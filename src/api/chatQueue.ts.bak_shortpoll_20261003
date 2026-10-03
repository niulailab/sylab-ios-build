import { RUNTIME_BASE } from '../config/runtime';
/**
 * Chat Queue Service API
 * 当 SSE 直连断开时，通过任务队列恢复/获取消息
 *
 * [2026-09-08] connectStream 改为 XMLHttpRequest + onprogress 分块读取：
 * 原生 RN（iOS/Android）的 fetch + response.body.getReader() 不流式，
 * 事件会全部憋到响应结束才一次性吐出，导致实时状态卡不切换、正文不逐字。
 * XHR.onprogress 在 iOS 原生 / Android 原生 / web PWA 三端都能分块推送。
 */

const QUEUE_BASE = `${RUNTIME_BASE}/chat-queue`;

export interface QueueSubmitRequest {
  bot_id: string;
  user_id: string;
  conversation_id?: string;
  additional_messages: Array<{ role: string; content: string; content_type: string }>;
  stream?: boolean;
  auto_save_history?: boolean;
  bearer_token?: string;
  mode?: 'primary' | 'standby';
}

export interface QueueSubmitResponse {
  task_id: string;
  status: string;
}

export interface QueueStatusResponse {
  task_id: string;
  status: 'pending' | 'processing' | 'completed' | 'failed' | 'cancelled';
  chat_id?: string;
  conversation_id?: string;
  content?: string;
  error?: string;
  events_count?: number;
  created_at?: string;
}

export interface QueueEvent {
  event_type: string;
  data: any;
  index: number;
}

export interface QueueEventsResponse {
  events: QueueEvent[];
  total: number;
  status: string;
}

export const chatQueueApi = {
  submit: async (req: QueueSubmitRequest, bearerToken: string): Promise<QueueSubmitResponse> => {
    const resp = await fetch(`${QUEUE_BASE}/submit`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${bearerToken}` },
      body: JSON.stringify(req),
    });
    if (!resp.ok) {
      let body: any = {};
      try { body = await resp.json(); } catch {}
      const err: any = new Error(body.error || `Queue submit failed: ${resp.status}`);
      err.status = resp.status;
      err.code = body.code;
      err.balance = body.balance;
      err.cost = body.cost;
      throw err;
    }
    return resp.json();
  },

  getStatus: async (taskId: string): Promise<QueueStatusResponse> => {
    const resp = await fetch(`${QUEUE_BASE}/status/${taskId}`);
    if (!resp.ok) throw new Error(`Queue status failed: ${resp.status}`);
    return resp.json();
  },

  getEvents: async (taskId: string, since: number = 0): Promise<QueueEventsResponse> => {
    const resp = await fetch(`${QUEUE_BASE}/events/${taskId}?since=${since}`);
    if (!resp.ok) throw new Error(`Queue events failed: ${resp.status}`);
    return resp.json();
  },

  start: async (taskId: string): Promise<void> => {
    // Start processing only when primary SSE fails (standby mode)
    await fetch(`${QUEUE_BASE}/start/${taskId}`, { method: 'POST' });
  },

  cancel: async (taskId: string): Promise<void> => {
    await fetch(`${QUEUE_BASE}/cancel/${taskId}`, { method: 'DELETE' });
  },

  /**
   * 连接队列 SSE 流（XHR 分块版）。
   * iOS/Android 原生 RN 下 fetch.body.getReader() 不流式，必须用 XHR.onprogress。
   */
  connectStream: (taskId: string, callbacks: {
    onDelta: (text: string, messageId?: string) => void;
    onToolCall?: (name: string, args: string, result?: string) => void;
    onComplete: (chatId: string, conversationId: string) => void;
    onIntermediateComplete?: (messageId: string, content: string) => void;
    onError: (error: Error) => void;
    onEventIndex?: (index: number) => void;
  }, since: number = 0): { abort: () => void } => {
    const url = `${QUEUE_BASE}/stream/${taskId}?since=${since}`;

    let aborted = false;
    let completed = false;
    let xhr: XMLHttpRequest | null = null;
    let idleWatchdog: ReturnType<typeof setTimeout> | null = null;

    const resetIdleWatchdog = () => {
      if (idleWatchdog) clearTimeout(idleWatchdog);
      idleWatchdog = setTimeout(() => {
        if (aborted || completed) return;
        console.warn('[ChatQueue] idle 90s, aborting for reconnect');
        try { xhr?.abort(); } catch (e) {}
        // abort 后由 onabort 走 onError → manager 退避重连 + backfill 补帧
      }, 90000);
    };

    const fail = (err: Error) => {
      if (completed || aborted) return;
      completed = true;
      if (idleWatchdog) clearTimeout(idleWatchdog);
      callbacks.onError(err);
    };

    try {
      xhr = new XMLHttpRequest();
      xhr.open('GET', url, true);
      xhr.responseType = 'text';
      xhr.timeout = 0; // 长连接不设整体超时，靠 idleWatchdog 判定卡死

      let buffer = '';
      let currentEvent = '';
      let processedLen = 0;

      const processChunk = () => {
        const text = xhr ? xhr.responseText : '';
        if (!text || text.length <= processedLen) return;
        buffer += text.slice(processedLen);
        processedLen = text.length;
        resetIdleWatchdog();

        const lines = buffer.split('\n');
        buffer = lines.pop() || '';

        for (const line of lines) {
          if (aborted || completed) break;
          const trimmed = line.trim();
          if (!trimmed) { currentEvent = ''; continue; }
          if (trimmed.startsWith('event:')) { currentEvent = trimmed.slice(6).trim(); continue; }
          if (trimmed.startsWith('data:')) {
            const dataStr = trimmed.slice(5).trim();
            if (!dataStr || dataStr === '[DONE]') continue;
            // 服务端收尾帧：event: done / data: {"status":"completed"}
            if (currentEvent === 'done') {
              completed = true;
              if (idleWatchdog) clearTimeout(idleWatchdog);
              chatQueueApi.getStatus(taskId)
                .then((st) => {
                  // [patch 2026-09-09] done 帧只代表流结束，成败以 /status 为准
                  if (st.status === 'failed') {
                    fail(new Error(st.error || '任务执行失败'));
                  } else {
                    // completed / cancelled / stale 都按完成收尾，结果以会话历史为准
                    callbacks.onComplete(st.chat_id || '', st.conversation_id || '');
                  }
                })
                .catch(() => callbacks.onComplete('', ''));
              return;
            }
            try {
              const parsed = JSON.parse(dataStr);
              const isEnvelope = parsed && typeof parsed === 'object' && 'event_type' in parsed && 'data' in parsed;
              const evType = isEnvelope ? parsed.event_type : currentEvent;
              const data = isEnvelope ? parsed.data : parsed;
              if (isEnvelope && typeof parsed.index === 'number') callbacks.onEventIndex?.(parsed.index);
              if (evType === 'conversation.message.delta' && data.content) {
                callbacks.onDelta(data.content, data.id);
              } else if (evType === 'conversation.message.completed') {
                if (data.type === 'function_call') {
                  try {
                    const tc = typeof data.content === 'string' ? JSON.parse(data.content || '{}') : data.content;
                    const name = tc.function?.name || tc.name || 'unknown';
                    const args = tc.function?.arguments || tc.arguments || '{}';
                    callbacks.onToolCall?.(name, args);
                  } catch (e) {}
                } else if (data.type === 'tool_response') {
                  const toolName = data.meta_data?.tool_name || '';
                  callbacks.onToolCall?.(toolName, '', data.content);
                } else if (data.type === 'answer' && data.id) {
                  // 中间轮次完成：通知上层 finalize 当前消息气泡，为下一轮腾出空间
                  callbacks.onIntermediateComplete?.(data.id, data.content || '');
                }
              } else if (evType === 'conversation.chat.completed') {
                completed = true;
                if (idleWatchdog) clearTimeout(idleWatchdog);
                callbacks.onComplete(data.chat_id || data.id || '', data.conversation_id || '');
                return;
              } else if (evType === 'conversation.chat.failed') {
                fail(new Error(data.last_error?.msg || 'Chat failed'));
                return;
              }
            } catch (e) {
              console.warn('[ChatQueue] Parse error:', dataStr.substring(0, 100));
            }
          }
        }
      };

      xhr.onprogress = processChunk;

      xhr.onload = () => {
        if (aborted) return;
        processChunk(); // 最终冲刷
        if (completed) return;
        // 流连接被服务端关闭但没收到 completed 帧：查权威状态
        if (idleWatchdog) clearTimeout(idleWatchdog);
        chatQueueApi.getStatus(taskId)
          .then((st) => {
            if (st.status === 'completed') callbacks.onComplete(st.chat_id || '', st.conversation_id || '');
            else fail(new Error('stream ended early: ' + st.status));
          })
          .catch(() => fail(new Error('stream ended')));
      };

      xhr.onerror = () => fail(new Error('网络连接失败'));
      xhr.ontimeout = () => fail(new Error('连接超时'));
      xhr.onabort = () => {
        if (aborted) return; // 主动 abort（重连/取消/离开）：静默
        if (completed) return;
        if (idleWatchdog) clearTimeout(idleWatchdog);
        callbacks.onError(new Error('连接已中断'));
      };

      resetIdleWatchdog();
      xhr.send();
    } catch (e: any) {
      fail(e instanceof Error ? e : new Error(String(e)));
    }

    return {
      abort: () => {
        aborted = true;
        if (idleWatchdog) clearTimeout(idleWatchdog);
        try { xhr?.abort(); } catch (e) {}
      },
    };
  },
};

/**
 * Queue-backed streaming adapter.
 * Drop-in replacement for sendMessageStream(...) in the chat page: same
 * callback semantics, but the task runs on the SERVER (primary mode), so it
 * survives page switches / app backgrounding. Reconnect + history backfill is
 * handled by the mount recovery logic in [id].tsx via getEvents().
 */
export interface QueueStreamCallbacks {
  onDelta: (text: string) => void;
  onToolCall?: (name: string, args: string, result?: string) => void;
  onComplete: (chatId: string, conversationId: string, tokens?: any) => void;
  onError: (error: Error) => void;
  onStatus?: (status: string) => void;
  onEventIndex?: (index: number) => void;
}

export function connectQueueStream(
  submitPromise: Promise<{ task_id: string; status: string }>,
  callbacks: QueueStreamCallbacks,
  registerTask?: (taskId: string, convId: string) => void,
  conversationId?: string
): { abort: () => void } {
  let aborted = false;
  let streamConn: { abort: () => void } | null = null;

  (async () => {
    try {
      const resp = await submitPromise;
      if (!resp || !resp.task_id) {
        callbacks.onError(new Error('Queue submit returned no task_id'));
        return;
      }
      const taskId = resp.task_id;
      if (registerTask) registerTask(taskId, conversationId || '');
      if (aborted) return;

      let connected = false;
      streamConn = chatQueueApi.connectStream(taskId, {
        onDelta: (text) => {
          if (!connected) { connected = true; callbacks.onStatus?.('streaming'); }
          callbacks.onDelta(text);
        },
        onToolCall: (name, args, result) => {
          callbacks.onStatus?.(result ? 'tool_complete' : 'tool_running');
          callbacks.onToolCall?.(name, args, result);
        },
        onComplete: (chatId, convId) => {
          callbacks.onComplete(chatId, convId, undefined);
        },
        onError: (err) => {
          callbacks.onError(err);
        },
        onEventIndex: (idx) => { callbacks.onEventIndex?.(idx); },
      }, 0);

      if (aborted) { try { streamConn.abort(); } catch (e) {} }
    } catch (e: any) {
      if (!aborted) callbacks.onError(new Error(e?.message || 'Queue stream setup failed'));
    }
  })();

  return {
    abort: () => {
      aborted = true;
      try { streamConn?.abort(); } catch (e) {}
    },
  };
}
