/**
 * BYOK 接口封装 (用户的自有模型)
 * 后端路由: /chat-queue/byok/* -> token-service /api/byok/*
 * 所有请求都带 user_id；响应 { code, msg, data } 由 webApiClient 拦截器解包为 data 部分
 */
import { webApiClient } from './client';

export interface ByokModel {
  id: number;
  user_id: string;
  provider: string;
  display_name: string;
  base_url: string;
  key_hint: string;
  model_name: string;
  is_default: number;
  status: number;
  last_test_ok: number | null;
  last_test_msg: string | null;
  created_at: string;
  updated_at: string;
}

export interface ByokUpsertPayload {
  user_id: string;
  provider?: string;
  display_name: string;
  base_url: string;
  api_key: string;
  model_name: string;
  is_default?: number;
  id?: number;
}

export interface ByokTestResult { ok: boolean; status: number; sample?: string; message?: string }
export interface ByokActive { active: boolean; id: number | null }

export interface ByokModelOption { id: string; name: string }
export interface ByokListModelsResult {
  ok: boolean; status?: number; models?: ByokModelOption[]; count?: number; msg?: string;
}

export const BYOK_PRESETS: Record<string,{name:string;url:string;placeholder:string;default_model:string}> = {
  deepseek: { name:'DeepSeek', url:'https://api.deepseek.com', placeholder:'sk-...', default_model:'deepseek-flash' },
  zhipu:    { name:'智谱 GLM', url:'https://open.bigmodel.cn/api/paas/v4', placeholder:'输入你的 key', default_model:'' },
  qwen:     { name:'通义千问', url:'https://dashscope.aliyuncs.com/compatible-mode/v1', placeholder:'sk-...', default_model:'' },
  kimi:     { name:'Kimi', url:'https://api.moonshot.cn/v1', placeholder:'输入你的 key', default_model:'' },
  doubao:   { name:'豆包', url:'https://ark.cn-beijing.volces.com/api/v3', placeholder:'输入 endpoint id', default_model:'' },
  custom:   { name:'自定义 OpenAI 兼容', url:'', placeholder:'https://...', default_model:'' },
};

export const byokApi = {
  list: (userId: string): Promise<ByokModel[]> =>
    webApiClient.get('/chat-queue/byok/models', { params: { user_id: userId } }).then(r => r.data as ByokModel[]),

  upsert: (payload: ByokUpsertPayload): Promise<ByokModel> =>
    webApiClient.post('/chat-queue/byok/upsert', payload).then(r => r.data as ByokModel),

  setDefault: (userId: string, id: number): Promise<{id:number}> =>
    webApiClient.post('/chat-queue/byok/set-default', { user_id: userId, id }).then(r => r.data as {id:number}),

  setActive: (userId: string, id: number, isDefault: number): Promise<{active:boolean,id:number}> =>
    webApiClient.post('/chat-queue/byok/set-active', { user_id: userId, id, is_default: isDefault }).then(r => r.data as {active:boolean,id:number}),

  remove: (userId: string, id: number): Promise<{}> =>
    webApiClient.post('/chat-queue/byok/delete', { user_id: userId, id }).then(r => r.data as {}),

  test: (payload: {user_id:string; base_url:string; api_key:string; model_name:string; provider?:string}): Promise<ByokTestResult> =>
    webApiClient.post('/chat-queue/byok/test', payload).then(r => r.data as ByokTestResult),

  // 拉取该端点真实可用模型列表（OpenAI 兼容 GET /models，服务端代拉，key 不出服务端）
  listModels: (payload: {base_url?:string; api_key?:string; provider?:string; user_id?:string; id?:number}): Promise<ByokListModelsResult> =>
    webApiClient.post('/chat-queue/byok/list-models', payload).then(r => r.data as ByokListModelsResult),

  active: (userId: string): Promise<ByokActive> =>
    webApiClient.post('/chat-queue/byok/active', { user_id: userId }).then(r => r.data as ByokActive),
};
