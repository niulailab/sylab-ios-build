export { Colors, Spacing, BorderRadius, FontSize, Shadows } from './theme';

export const OPENAPI_CONNECTOR_ID = '1024';

export const API_PATHS = {
  // 认证 (WebAPI, 无认证/Session)
  LOGIN: '/api/passport/web/email/login/',
  REGISTER: '/api/passport/web/email/register/v2/',
  LOGOUT: '/api/passport/web/logout/',
  ME: '/api/passport/account/info/v2/',

  // Bot (OpenAPI, Bearer PAT)
  BOT_DETAIL: (id: string) => `/v1/bots/${id}`,
  BOT_ONLINE_INFO: '/v1/bot/get_online_info',

  // 聊天 (OpenAPI, Bearer PAT)
  CHAT: '/v3/chat',
  CHAT_RETRIEVE: '/v3/chat/retrieve',
  CHAT_MESSAGE_LIST: '/v3/chat/message/list',
  CHAT_CANCEL: '/v3/chat/cancel',

  // 会话 (OpenAPI, Bearer PAT)
  CONVERSATIONS: '/v1/conversations',
  CONVERSATION_CREATE: '/v1/conversation/create',
  CONVERSATION_RETRIEVE: '/v1/conversation/retrieve',
  CONVERSATION_MESSAGE_LIST: '/v1/conversation/message/list',
  CONVERSATION_CLEAR: (id: string) => `/v1/conversations/${id}/clear`,

  // 知识库 (WebAPI, Session)
  KNOWLEDGE_LIST: '/api/knowledge/list',
  KNOWLEDGE_CREATE: '/api/knowledge/create',
  KNOWLEDGE_DETAIL: (id: string) => `/api/knowledge/detail?id=${id}`,
  KNOWLEDGE_DELETE: '/api/knowledge/delete',
  KNOWLEDGE_UPDATE: '/api/knowledge/update',
  KNOWLEDGE_DOCUMENT_LIST: '/api/knowledge/document/list',
  KNOWLEDGE_DOCUMENT_CREATE: '/api/knowledge/document/create',
  KNOWLEDGE_DOCUMENT_DELETE: '/api/knowledge/document/delete',
  KNOWLEDGE_DOCUMENT_PROGRESS: '/api/knowledge/document/progress/get',

  // 数据库 Memory (WebAPI, Session)
  DATABASE_LIST: '/api/knowledge/database/list',
  DATABASE_GET_BY_ID: '/api/knowledge/database/get_by_id',
  DATABASE_ADD: '/api/knowledge/database/add',
  DATABASE_DELETE: '/api/knowledge/database/delete',
  DATABASE_LIST_RECORDS: '/api/knowledge/database/list_records',
  DATABASE_UPDATE_RECORDS: '/api/knowledge/database/update_records',

  // 记忆 (WebAPI, Session)
  MEMORY_VARIABLES: '/api/knowledge/memory/get_memory_variable_meta',
  MEMORY_SET_KV: '/api/knowledge/memory/set_kv_memory',
  MEMORY_DEL_PROFILE: '/api/knowledge/memory/del_profile_memory',

  // 工作流 (WebAPI, Session)
  WORKFLOW_LIST: '/api/workflow_api/workflow_list',
  WORKFLOW_DETAIL: '/api/workflow_api/workflow_detail',
  WORKFLOW_CREATE: '/api/workflow_api/create',
  WORKFLOW_SAVE: '/api/workflow_api/save',
  WORKFLOW_DELETE: '/api/workflow_api/delete',
  WORKFLOW_PUBLISH: '/api/workflow_api/publish',
  WORKFLOW_TEST_RUN: '/api/workflow_api/test_run',
  WORKFLOW_TEST_RESUME: '/api/workflow_api/test_resume',

  // 插件 (WebAPI, Session)
  PLUGIN_LIST: '/api/plugin_api/get_playground_plugin_list',
  PLUGIN_DETAIL: '/api/plugin_api/get_plugin_info',
  PLUGIN_CREATE: '/api/plugin_api/create_api',
  PLUGIN_PUBLISH: '/api/plugin_api/publish_plugin',
  PLUGIN_DEBUG: '/api/plugin_api/debug_api',

  // 市场 (WebAPI, Session)
  MARKET_CATEGORIES: '/api/marketplace/category/list',
  MARKET_SEARCH: '/api/marketplace/search',
  MARKET_PRODUCT: '/api/marketplace/product',

  // 文件上传 (WebAPI, Session)
  UPLOAD: '/api/common/upload/apply_upload_action',

  // 用户 (WebAPI, Session)
  USER_UPDATE_PROFILE: '/api/user/update_profile',
  USER_UPLOAD_AVATAR: '/api/web/user/update/upload_avatar/',

  // PAT管理 (WebAPI, Session)
  PAT_LIST: '/api/permission_api/pat/list',
  PAT_CREATE: '/api/permission_api/pat/create',
  PAT_DELETE: '/api/permission_api/pat/delete',

  // 积分服务 (独立服务)
  CREDITS_BALANCE: '/token-api/api/balance',
  CREDITS_TRANSACTIONS: '/token-api/api/transactions',
  CREDITS_PRICING: '/token-api/api/pricing',
  CREDITS_ACTION_PRICING: '/token-api/api/action/pricing',
  CREDITS_RECHARGE: '/token-api/api/recharge',
  CREDITS_CARD_REDEEM: '/token-api/api/card/redeem',
  VERIFICATION_SEND_CODE: '/token-api/api/verification/send-code',
  VERIFICATION_VERIFY: '/token-api/api/verification/verify',
  CONVERSATION_DELETE: (id: string) => `/v1/conversations/${id}`,
  RESET_PASSWORD: '/api/passport/web/email/reset_password/',

} as const;
