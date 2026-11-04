import { webApiClient } from './client';

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
 */

const PAT_NAME = 'sylab-app';
const PAT_API = '/api/permission_api/pat';

/** 旧版本写死的主账号 PAT，出现在本地存储里一律视为脏数据丢弃 */
export const LEAKED_PAT =
  'pat_fb5f8dccaaf858b78152bff3788686c76a46a4bfe95736eb94441da0d40e6ed4';

/** 用当前 session 签发一个本用户的 PAT；失败返回 null，不抛错 */
export async function createPersonalPat(): Promise<string | null> {
  try {
    // 先清掉同名的旧 token，避免每次登录都堆一条（每人恒定 1 条）
    try {
      const lr: any = await webApiClient.get(`${PAT_API}/list_personal_access_tokens`, {
        params: { page: 1, size: 50 },
      });
      const list: any[] = lr?.personal_access_tokens || lr?.data?.personal_access_tokens || [];
      for (const it of list) {
        if (it?.name === PAT_NAME && it?.id) {
          try {
            await webApiClient.post(`${PAT_API}/delete_personal_access_token_and_permission`, {
              id: it.id,
            });
          } catch {}
        }
      }
    } catch {
      // 清理失败不影响主流程
    }

    const r: any = await webApiClient.post(
      `${PAT_API}/create_personal_access_token_and_permission`,
      { name: PAT_NAME, duration_day: '365' },
    );
    const token = r?.token || r?.data?.token;
    if (typeof token === 'string' && token.indexOf('pat_') === 0) {
      return token;
    }
    console.warn('[pat] create returned unexpected payload');
    return null;
  } catch (e) {
    console.warn('[pat] createPersonalPat failed:', e);
    return null;
  }
}
