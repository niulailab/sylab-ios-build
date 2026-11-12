import { create } from 'zustand';
import { Storage } from '../utils/storage';
import { authApi } from '../api/auth';
import { resetSpaceCache } from '../api/bot';
import { createPersonalPat, LEAKED_PAT } from '../api/pat';
import { setSessionId, setBearerToken, clearAuth, setPatRefresher } from '../api/client';
import { normalizeFileUrl } from '../utils/avatarUrl';
import type { UserInfo, LoginResponse } from '../types/api';

interface AuthState {
  user: UserInfo | null;
  sessionId: string | null;
  patToken: string | null;
  isLoading: boolean;
  isRestoring: boolean;

  restore: () => Promise<void>;
  login: (account: string, password: string) => Promise<void>;
  register: (email: string, password: string) => Promise<void>;
  logout: () => Promise<void>;
  setUser: (user: UserInfo) => void;
}

const SESSION_KEY = 'sylab_session_id';
const PAT_KEY = 'sylab_pat_token';
const USER_KEY = 'sylab_user';

export const useAuthStore = create<AuthState>((set, get) => ({
  user: null,
  sessionId: null,
  patToken: null,
  isLoading: false,
  isRestoring: true,

  restore: async () => {
    try {
      const [sessionId, patToken, userStr] = await Promise.all([
        Storage.getItem(SESSION_KEY),
        Storage.getItem(PAT_KEY),
        Storage.getItem(USER_KEY),
      ]);

      if (sessionId) {
        setSessionId(sessionId);
        set({ sessionId });
      }
      // v1.0.51: 老版本写死的主账号 PAT 已泄露，本地存到这个值一律丢弃重签
      // v1.0.52: 冷启动一律用当前 session 重签一次。任何本地脏 PAT（已吊销 / 串号 / 泄露值）
      //          都能自愈，避免升级后首次打开历史消息空白、必须手动重新登录一次
      // v1.0.54: 本地有可用 PAT 就直接用，不再每次冷启动强制重签。
      // 旧实现（v1.0.52）冷启动必签，而签发是「先删后建」：弱网下删除成功、创建失败，
      // 账号下 PAT 会彻底消失，本地那份同时失效 → 所有 OpenAPI 401 → 会话列表空白，
      // 必须重新登录才恢复。真失效时由 api/client 的 401 自愈钩子兜底重签。
      const usablePat = patToken && patToken !== LEAKED_PAT ? patToken : null;
      if (usablePat) {
        setBearerToken(usablePat);
        set({ patToken: usablePat });
      } else if (sessionId) {
        const ownPat = await createPersonalPat();
        if (ownPat) {
          setBearerToken(ownPat);
          await Storage.setItem(PAT_KEY, ownPat);
          set({ patToken: ownPat });
        } else {
          console.warn('[auth] restore: no usable PAT, openapi calls may 401');
        }
      }
      if (userStr) {
        set({ user: JSON.parse(userStr) });
      }
    } catch (e) {
      console.warn('Auth restore failed:', e);
    } finally {
      set({ isRestoring: false });
    }
  },

  login: async (account: string, password: string) => {
    set({ isLoading: true });
    try {
      const result = await authApi.login(account, password);
      const data = result?.data || result;

      const userId = data.user_id_str || data.user_id || data.user_id_str_id || '';
      const user: UserInfo = {
        id: String(userId),
        name: (() => {
          const n = data.screen_name || data.name || account || '';
          return /^\d+$/.test(n.trim()) ? '用户' : n;
        })(),
        email: data.email || account,
        avatar_url: normalizeFileUrl(data.avatar_url) || '',
        created_at: String(data.user_create_time || Date.now()),
      };

      // Extract session_key from login response
      const sessionKey = data?.session_key || '';
      if (sessionKey) {
        await Storage.setItem(SESSION_KEY, sessionKey);
        setSessionId(sessionKey);
      }

      // v1.0.51: 用当前 session 现场签发本用户的 PAT（不再共用主账号令牌）
      const ownPat = await createPersonalPat();
      if (ownPat) {
        await Storage.setItem(PAT_KEY, ownPat);
        setBearerToken(ownPat);
      } else {
        console.warn('[auth] login: create own PAT failed, openapi calls may 401');
      }
      await Storage.setItem(USER_KEY, JSON.stringify(user));
      set({ user, sessionId: sessionKey || null, patToken: ownPat || null, isLoading: false });
    } catch (error) {
      set({ isLoading: false });
      throw error;
    }
  },

  register: async (email: string, password: string) => {
    set({ isLoading: true });
    try {
      const resp = await authApi.register(email, password);
      if (resp.code !== 0) {
        throw new Error(resp.msg || '注册失败');
      }
      const loginResp = await authApi.login(email, password);
      if (loginResp.code === 0) {
        const data = loginResp.data;
        let sessionKey = data?.session_key || '';
        let userId = data?.user_id_str || data?.user_id || '';
        
        if (sessionKey) {
          await setSessionId(sessionKey);
          set({ sessionId: sessionKey });
        }
        if (userId) {
          await Storage.setItem('sylab_user_id', userId);
        }
        
        try {
          const meResp = await authApi.getMe();
          if (meResp.code === 0 && meResp.data) {
            const raw = meResp.data as any;
            const user = { ...raw, avatar_url: normalizeFileUrl(raw.avatar_url || raw.avatar) || raw.avatar_url || '' };
            await Storage.setItem(USER_KEY, JSON.stringify(user));
            set({ user });
          }
        } catch {}
      }
    } catch (error: any) {
      throw error;
    } finally {
      set({ isLoading: false });
    }
  },

  logout: async () => {
    resetSpaceCache();
    try {
      await authApi.logout();
    } catch {}
    await Promise.all([
      Storage.deleteItem(SESSION_KEY),
      Storage.deleteItem(PAT_KEY),
      Storage.deleteItem(USER_KEY),
    ]);
    clearAuth();
    set({ user: null, sessionId: null, patToken: null });
  },

  setUser: (user) => set({ user }),
}));

// v1.0.54: 给 OpenAPI 客户端注册 PAT 自愈钩子。
// 收到 401 时用当前 session 现场重签一次 PAT 并重试原请求，避免「列表空白 + 被迫重新登录」。
// 并发去重：同一时刻只允许一次签发，其余请求复用同一个 Promise。
let _patRefreshing: Promise<string | null> | null = null;
setPatRefresher(async () => {
  if (_patRefreshing) return _patRefreshing;
  _patRefreshing = (async () => {
    const t = await createPersonalPat();
    if (t) {
      setBearerToken(t);
      try {
        await Storage.setItem(PAT_KEY, t);
      } catch (e) {}
      useAuthStore.setState({ patToken: t });
    }
    return t;
  })();
  try {
    return await _patRefreshing;
  } finally {
    _patRefreshing = null;
  }
});
