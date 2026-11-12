/**
 * 会话消息预览：并发闸门 + 短缓存
 *
 * [FIX N+1 请求风暴 2026-11-12]
 * 会话列表页原先对每个会话单独请求 /v1/conversation/message/list：
 *   1) 没有任何并发限制，50 个会话就是 50 个请求同时打出去
 *   2) chat.tsx 的 enrichConv 不传 page_size，后端按默认条数返回整段历史，响应体巨大
 *   3) 首页和对话页两个 tab 各拉一遍，互不复用
 * 叠加上层的事件风暴（每来一个流事件就整表重刷），一瞬间就是 200 个请求。
 *
 * 这里做三件事：
 *   1) 并发闸门：同一时刻最多 4 个预览请求在飞，其余排队，不再瞬间打满连接池
 *   2) 结果缓存：同一会话 30 秒内复用，两个 tab 共享同一份
 *   3) 同会话去重：已在飞行中的请求直接复用同一个 Promise
 */

import { chatApi } from '../api/chat';

const TTL = 30_000;
const MAX_CONCURRENCY = 4;

type Msg = any;

const cache = new Map<string, { at: number; items: Msg[] }>();
const inflight = new Map<string, Promise<Msg[]>>();

let running = 0;
const waiters: Array<() => void> = [];

function acquire(): Promise<void> {
  if (running < MAX_CONCURRENCY) {
    running += 1;
    return Promise.resolve();
  }
  return new Promise<void>((resolve) => waiters.push(resolve));
}

function release() {
  const next = waiters.shift();
  if (next) {
    next(); // 名额直接转交，running 保持不变
  } else {
    running -= 1;
  }
}

/** 取会话最近若干条消息，带缓存与并发控制。失败返回空数组，不抛错。 */
export function getConvMessagesCached(convId: string, pageSize: number = 5): Promise<Msg[]> {
  if (!convId) return Promise.resolve([]);

  const hit = cache.get(convId);
  if (hit && Date.now() - hit.at < TTL) return Promise.resolve(hit.items);

  const flying = inflight.get(convId);
  if (flying) return flying;

  const task = (async () => {
    await acquire();
    try {
      const res: any = await chatApi.getMessages(convId, { page_num: 1, page_size: pageSize });
      const items: Msg[] = res?.items || [];
      cache.set(convId, { at: Date.now(), items });
      return items;
    } catch (e) {
      return [];
    } finally {
      release();
      inflight.delete(convId);
    }
  })();

  inflight.set(convId, task);
  return task;
}

/** 批量取，返回与入参同序的结果数组 */
export function getConvMessagesBatch(convIds: string[], pageSize: number = 5): Promise<Msg[][]> {
  return Promise.all(convIds.map((id) => getConvMessagesCached(id, pageSize)));
}

/** 会话内容变化后主动失效；不传则全清 */
export function invalidateConvMessages(convId?: string) {
  if (convId) cache.delete(convId);
  else cache.clear();
}
