import axios, { AxiosInstance, AxiosError } from 'axios';
import Constants from 'expo-constants';
import { Platform } from 'react-native';

import { RUNTIME_BASE as API_BASE, getRuntimeBase, reportBaseFailure } from '../config/runtime';
const OPEN_API_BASE = API_BASE;
const ENABLE_LOG = Constants.expoConfig?.extra?.EXPO_PUBLIC_ENABLE_API_LOG === 'true';

type AuthMode = 'none' | 'session' | 'bearer' | 'apikey';

interface ClientOptions {
  baseURL: string;
  authMode: AuthMode;
  sessionId?: string;
  bearerToken?: string;
  apiKey?: string;
}

// v1.0.54: OpenAPI(PAT) 401 自愈钩子。由 store/auth 注册。
// 收到 401 时用当前 session 重签一次 PAT 并重试原请求，
// 不再直接失败（旧行为：PAT 失效 → 会话列表/消息全 401 → 界面空白，只能重新登录）
let _patRefresher: (() => Promise<string | null>) | null = null;
export function setPatRefresher(fn: (() => Promise<string | null>) | null) {
  _patRefresher = fn;
}

function createClient(options: ClientOptions): AxiosInstance {
  const { baseURL, authMode, sessionId, bearerToken, apiKey } = options;

  const client = axios.create({
    baseURL,
    timeout: 30000,
    headers: { 'Content-Type': 'application/json' },
    withCredentials: true,  // 跨域时携带 cookie
  });

  // 请求拦截器：注入认证头
  client.interceptors.request.use((config) => {
    // 双通道：每次请求用当前健康的出口（仅当配置了 baseURL 且 url 非绝对地址）
    if (config.baseURL && !/^https?:\/\//i.test(config.url || '')) {
      config.baseURL = getRuntimeBase();
    }
    switch (authMode) {
      case 'session':
        if (options.sessionId) {
          config.headers['X-Session-Id'] = options.sessionId;
          config.headers['Cookie'] = `session_key=${options.sessionId}`;
        }
        // Also add bearer token for dual-auth endpoints
        if (options.bearerToken) {
          config.headers['Authorization'] = `Bearer ${options.bearerToken}`;
        }
        break;
      case 'bearer':
        if (options.bearerToken) {
          config.headers['Authorization'] = `Bearer ${options.bearerToken}`;
        }
        break;
      case 'apikey':
        if (apiKey) {
          config.headers['X-API-Key'] = apiKey;
        }
        break;
    }
    if (ENABLE_LOG) {
      console.log(`[API] ${config.method?.toUpperCase()} ${config.baseURL}${config.url}`);
    }
    return config;
  });

  // 响应拦截器：统一解包 + 错误处理
  client.interceptors.response.use(
    (response) => {
      const body = response.data;
      // 如果响应是 { code, msg, data } 格式，解包 data
      if (body && typeof body === 'object' && 'code' in body && 'data' in body) {
        if (body.code !== 0 && body.code !== 200) {
          return Promise.reject(new Error(body.msg || body.message || '请求失败'));
        }
        return { ...response, data: body.data };
      }
      // 有 code 但无 data 的响应(token-api验证码等)，直接返回 body
      if (body && typeof body === 'object' && 'code' in body) {
        if (body.code !== 0 && body.code !== 200) {
          return Promise.reject(new Error(body.msg || body.message || '请求失败'));
        }
        return { ...response, data: body };
      }
      return response;
    },
    async (error: AxiosError) => {
      if (ENABLE_LOG) {
        console.error(`[API Error] ${error.response?.status} ${error.config?.url}`, error.message);
      }
      // Debug: capture detailed network error info
      if (!error.response) {
        reportBaseFailure();
        const e = error as any;
        const parts: string[] = [];
        parts.push(`msg=${e.message}`);
        parts.push(`code=${e.code}`);
        if (e.errno) parts.push(`errno=${e.errno}`);
        if (e.syscall) parts.push(`syscall=${e.syscall}`);
        if (e.hostname) parts.push(`hostname=${e.hostname}`);
        if (e.host) parts.push(`host=${e.host}`);
        if (e.port) parts.push(`port=${e.port}`);
        if (e.config?.baseURL) parts.push(`base=${e.config.baseURL}`);
        if (e.config?.url) parts.push(`url=${e.config.url}`);
        console.error(`[NET_DEBUG] ${parts.join(" | ")}`);
        // Show alert with debug info on network error
        // v111: removed debug alert, keep console.error only
      }
      if (error.response?.status === 401) {
        // v1.0.54: bearer(PAT) 401 先用 session 重签一次 PAT 再重试原请求。
        // PAT 可能被别的设备/旧版本删掉，或签发时网络中断；重签能无感自愈。
        const cfg: any = (error as any).config || {};
        if (authMode === 'bearer' && _patRefresher && !cfg._patRetried) {
          cfg._patRetried = true;
          try {
            const fresh = await _patRefresher();
            if (fresh) {
              setBearerToken(fresh);
              cfg.headers = Object.assign({}, cfg.headers || {}, {
                Authorization: 'Bearer ' + fresh,
              });
              return client.request(cfg);
            }
          } catch (e) {
            console.warn('[API] pat refresh failed', e);
          }
        }
        // 401 未授权，抛出特殊错误让上层处理踢下线
        const authError = new Error('UNAUTHORIZED') as any;
        authError.code = 401;
        return Promise.reject(authError);
      }
      return Promise.reject(error);
    }
  );

  return client;
}

// 4 种客户端实例
let _sessionId: string | undefined;
// v1.0.51: 不再内置任何 PAT。Bearer 令牌由 store/auth 在登录后用当前 session 现场签发（见 api/pat.ts）
let _bearerToken: string | undefined;

export function setSessionId(id: string) { _sessionId = id; }
export function setBearerToken(token: string) { _bearerToken = token; }
export function clearAuth() { _sessionId = undefined; _bearerToken = undefined; }
export function getBearerToken() { return _bearerToken; }
export function getSessionId() { return _sessionId; }

export const webApiClient = createClient({
  baseURL: API_BASE,
  authMode: 'session',
  get sessionId() { return _sessionId; },
  get bearerToken() { return _bearerToken; },
});

export const openApiClient = createClient({
  baseURL: OPEN_API_BASE,
  authMode: 'bearer',
  get bearerToken() { return _bearerToken; },
});

export const noAuthClient = createClient({
  baseURL: API_BASE,
  authMode: 'none',
});

export function createApiKeyClient(apiKey: string): AxiosInstance {
  return createClient({
    baseURL: API_BASE,
    authMode: 'apikey',
    apiKey,
  });
}

// 雪花 ID 安全处理：递归把 number 类型的大整数转 string
export function normalizeIds(obj: any): any {
  if (obj === null || obj === undefined) return obj;
  if (typeof obj === 'number') {
    // 超过 JS 安全整数范围的数字转 string
    if (Math.abs(obj) > Number.MAX_SAFE_INTEGER) {
      return String(obj);
    }
    return obj;
  }
  if (typeof obj === 'string') return obj;
  if (Array.isArray(obj)) {
    return obj.map(normalizeIds);
  }
  if (typeof obj === 'object') {
    const result: any = {};
    for (const key of Object.keys(obj)) {
      // 常见 ID 字段名
      if (key.endsWith('_id') || key === 'id' || key.endsWith('_ids')) {
        result[key] = typeof obj[key] === 'number' ? String(obj[key]) : obj[key];
      } else {
        result[key] = normalizeIds(obj[key]);
      }
    }
    return result;
  }
  return obj;
}
