/**
 * Bot 模块
 * - 列表/搜索 → WebAPI (Session): /api/intelligence_api/search/get_draft_intelligence_list
 * - 详情 → OpenAPI (Bearer PAT): /v1/bots/:id
 */
import { webApiClient } from './client';
import { API_PATHS, OPENAPI_CONNECTOR_ID } from '../constants';
import type { SnowflakeId } from '../types/api';

const FALLBACK_SPACE_ID = '7666842042261045248';

// v1.0.50 fix: 原来这里硬编码了主账号的 space_id，导致**所有登录用户**（包括新注册账号）
// 都去查主账号的 space，看到主账号技能库里的技能卡，属于跨账号数据泄露。
// 现在改为按当前登录用户动态解析自己的 space（/api/playground_api/space/list），
// 优先取 personal space；解析失败才回落到旧值，避免老用户白屏。
let cachedSpaceId: string | null = null;

/** 退出登录时调用，清掉 space 缓存 */
export function resetSpaceCache() {
  cachedSpaceId = null;
}

async function resolveSpaceId(): Promise<string> {
  if (cachedSpaceId) return cachedSpaceId;
  try {
    const r = await webApiClient.post('/api/playground_api/space/list', {});
    const d = r.data?.data || r.data;
    const list: any[] = d?.bot_space_list || [];
    if (list.length > 0) {
      const personal = list.find((s: any) => Number(s?.space_type) === 1) || list[0];
      const id = personal?.id;
      if (id !== undefined && id !== null && String(id) !== '0') {
        cachedSpaceId = String(id);
        return cachedSpaceId;
      }
    }
  } catch (e) {
    console.warn('[bot] resolveSpaceId failed, fallback:', e);
  }
  return FALLBACK_SPACE_ID;
}


/** 归一化 Bot 列表项（后端字段名可能不统一，可能嵌套 basic_info/publish_info） */
function normalizeBotItem(raw: any) {
  const item = raw.basic_info || raw;
  const connectors =
    (raw.publish_info && raw.publish_info.connectors) || item.connector_ids || [];
  return {
    id: String(item.bot_id || item.id || ''),
    name: item.bot_name || item.name || '',
    description: item.description || '',
    icon_url: item.icon_url || item.avatar_url || '',
    avatar_url: item.icon_url || item.avatar_url || '',
    connector_ids: connectors,
    status: item.status ?? 1,
    published: raw.publish_info
      ? !!raw.publish_info.has_published
      : item.published ?? true,
    // 保留原始字段
    ...raw,
  };
}

export const botApi = {
  // ────────────── WebAPI (Session) ──────────────

  /** Bot 列表 (WebAPI POST) */
  list: async (params?: { page?: number; page_size?: number }) => {
    try {
      const pageSize = params?.page_size || 20;
      const page = params?.page || 1;
      const resp = await webApiClient.post(
        '/api/intelligence_api/search/get_draft_intelligence_list',
        {
          space_id: await resolveSpaceId(),
          count: pageSize,
          offset: (page - 1) * pageSize,
        },
      );
      const data = resp.data?.data || resp.data;
      const list: any[] = data.intelligences || data.intelligence_list || data.items || [];
      return {
        items: list.map(normalizeBotItem),
        total: data.total || list.length,
        page,
        page_size: pageSize,
      };
    } catch {
      return { items: [], total: 0, page: 1, page_size: 20 };
    }
  },

  /** Bot 搜索 (WebAPI POST) */
  search: async (keyword: string, params?: { page?: number; page_size?: number }) => {
    try {
      const pageSize = params?.page_size || 20;
      const page = params?.page || 1;
      const resp = await webApiClient.post(
        '/api/intelligence_api/search/get_draft_intelligence_list',
        {
          space_id: await resolveSpaceId(),
          keyword,
          count: pageSize,
          offset: (page - 1) * pageSize,
        },
      );
      const data = resp.data?.data || resp.data;
      const list: any[] = data.intelligences || data.intelligence_list || data.items || [];
      return {
        items: list.map(normalizeBotItem),
        total: data.total || list.length,
        page,
        page_size: pageSize,
      };
    } catch {
      return { items: [], total: 0, page: 1, page_size: 20 };
    }
  },

  // ────────────── OpenAPI (Bearer PAT) ──────────────

  /** Bot 详情 (OpenAPI) */
  get: (id: SnowflakeId) =>
    webApiClient.get(API_PATHS.BOT_DETAIL(id)).then((r) => {
      const data = r.data?.data || r.data;
      return data;
    }),

  // ────────────── 工具方法 ──────────────

  /** 检查 Bot 是否支持 OpenAPI 调用 */
  isOpenApiEnabled: (bot: any): boolean =>
    bot?.connector_ids?.includes(OPENAPI_CONNECTOR_ID) ||
    bot?.connector_id === OPENAPI_CONNECTOR_ID,
};
