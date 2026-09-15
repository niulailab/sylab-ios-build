import axios, { AxiosInstance, AxiosError } from 'axios';
import Constants from 'expo-constants';
import { Platform } from 'react-native';

import { RUNTIME_BASE as API_BASE } from '../config/runtime';
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
    (error: AxiosError) => {
      if (ENABLE_LOG) {
        console.error(`[API Error] ${error.response?.status} ${error.config?.url}`, error.message);
      }
      // Debug: capture detailed network error info
      if (!error.response) {
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
        try {
          const { Alert } = require("react-native");
          Alert.alert("网络调试", parts.join("\n"));
        } catch (_) {}
      }
      if (error.response?.status === 401) {
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
let _bearerToken: string | undefined = process.env.EXPO_PUBLIC_DEFAULT_PAT || "pat_f360e4508904a857bf1466629c9ecc4f53abd2c4cb6572fa76667fceefb24de4";

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
