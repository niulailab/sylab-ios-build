import { webApiClient } from './client';
import { Storage } from '../utils/storage';

/**
 * v1.0.51 安全修复
 *
 * 旧实现：App 里写死了一个主账号的 PAT（pat_fb5f8dcc...），所有登录用户都用它调
 * OpenAPI（/v1/*、/v3/chat 等）。后果有两个：
 *   1. 越权 —— 任何用户的 OpenAPI 调用都以主账号身份执行；
 *   2. 泄露 —— 这个 PAT 明文打包在客户端，反编译就能拿到，可用来读主账号的知识库、跑 bot。
 *
 * 现在改为：登录后由当前 session 现场签发属于本用户的 PAT，存本地复用。
 * 走的是 Coze 自带的 PAT 管理接口（session 鉴权，userID 取自 ctx，不可能串号）。
 *
 * v1.0.54 两个关键修复（对应「一段时间没打开就要重新登录、会话列表消失」）：
 *   A. 先建后删。旧实现先删同名旧 token 再创建，弱网或冷启动超时时删除成功、创建失败，
 *      账号下就一条 PAT 都不剩，本地存的那份同时失效 → 全部 OpenAPI 401 → 列表空白。
 *   B. 名字带设备指纹（sylab-app-<deviceTag>）。旧实现固定 'sylab-app'，
 *      两台设备各自冷启动时会互相删掉对方的 token。
 */

const PAT_PREFIX = 'sylab-app';
const LEGACY_PAT_NAME = 'sylab-app';
const PAT_NAME = 'sylab-app';
const DEVICE_KEY = 'sylab_device_id';

/** 旧版本写死的主账号 PAT，出现在本地存储里一律视为脏数据丢弃 */
export const LEAKED_PAT =
  'pat_fb5f8dccaaf858b78152bff3788686c76a46a4bfe95736eb94441da0d40e6ed4';

let _tag: string | null = null;

async function deviceTag(): Promise<string> {
  if (_tag) return _tag;
  try {
    let id = await Storage.getItem(DEVICE_KEY);
    if (!id) {
      id = Math.random().toString(36).slice(2, 10);
      await Storage.setItem(DEVICE_KEY, id);
    }
    _tag = String(id).slice(0, 10) || 'nodev';
  } catch (e) {
    _tag = 'nodev';
  }
  return _tag as string;
}

/** 用当前 session 签发一个本用户的 PAT；失败返回 null，不抛错 */
export async function createPersonalPat(): Promise<string | null> {
  try {
    const name = PAT_PREFIX + '-' + (await deviceTag());

    // A. 先建：创建失败时旧 token 仍然有效，不会把用户踢成空白
    const r: any = await webApiClient.post(
      '/api/permission_api/pat/create_personal_access_token_and_permission',
      { name, duration_day: '365' },
      { timeout: 12000 },
    );
    const token = r?.token || r?.data?.token;
    const newId =
      r?.personal_access_token?.id ||
      r?.data?.personal_access_token?.id ||
      r?.id ||
      r?.data?.id;
    if (!(typeof token === 'string' && token.indexOf('pat_') === 0)) {
      console.warn('[pat] create returned unexpected payload');
      return null;
    }

    // B. 建成后再清：只删「本设备同名但不是刚建的那条」和老版本遗留的共享名
    try {
      const lr: any = await webApiClient.get(
        '/api/permission_api/pat/list_personal_access_tokens',
        { params: { page: 1, size: 50 }, timeout: 8000 },
      );
      const list: any[] =
        lr?.personal_access_tokens || lr?.data?.personal_access_tokens || [];
      for (const it of list) {
        const n = it?.name;
        const id = it?.id;
        if (!id) continue;
        if (newId && String(id) === String(newId)) continue;
        if (n === name || n === LEGACY_PAT_NAME) {
          try {
            await webApiClient.post(
              '/api/permission_api/pat/delete_personal_access_token_and_permission',
              { id },
              { timeout: 8000 },
            );
          } catch (e) {}
        }
      }
    } catch (e) {
      // 清理失败不影响主流程
    }

    return token;
  } catch (e) {
    console.warn('[pat] createPersonalPat failed:', e);
    return null;
  }
}

export { PAT_NAME };
