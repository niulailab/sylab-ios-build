import { getRuntimeBase, reportBaseFailure } from '../config/runtime';

export interface TokenUsage {
  input: number;
  output: number;
  total: number;
}

export interface SseCallbacks {
  onDelta: (text: string) => void;
  onToolCall?: (name: string, args: string, result?: string) => void;
  onComplete: (chatId: string, conversationId: string, tokens?: TokenUsage) => void;
  onMessageComplete?: () => void;
  onError: (error: Error) => void;
  onStatus?: (status: string) => void;
}

export interface ChatRequest {
  bot_id: string;
  user_id: string;
  conversation_id?: string;
  additional_messages: Array<{
    role: string;
    content: string;
    content_type: string;
  }>;
  stream?: boolean;
  auto_save_history?: boolean;
}

function estimateTokens(text: string): number {
  if (!text) return 0;
  return Math.ceil(text.length / 3);
}

/**
 * 2026-10-03: 发送通道改为「队列短连接」。
 * 根因：中国移动 DPI 选择性拦截 POST /v3/chat 长连接（当天其它接口 900+ 请求
 * 全 200，唯独 v3/chat 0 次到源站，直连/CF 同路径特征均被拦）。
 * 解法：手机端不再直连 v3/chat，改为 submit(mode=primary) 由服务器侧发起
 * v3/chat，再用 /events 短连接轮询增量事件；两者都是几百毫秒的普通短连接，
 * 无 SSE 长连接特征，DPI 不拦。对外签名/回调不变，聊天页零改动。
 */
export function sendMessageStream(
  body: ChatRequest,
  bearerToken: string,
  callbacks: SseCallbacks
): { abort: () => void } {
  const convId = body.conversation_id;
  let aborted = false;
  let finished = false;
  let pollTimer: ReturnType<typeof setTimeout> | null = null;
  let thinkingTimer: ReturnType<typeof setInterval> | null = null;
  let thinkingPhase = 0;

  let taskId = '';
  let lastChatId = '';
  let lastConversationId = convId || '';
  let lastTokenUsage: TokenUsage | undefined;
  let fullAssistantContent = '';
  let sinceIndex = 0;
  let consecutiveErrors = 0;
  let gotAnyEvent = false;

  const clearTimers = () => {
    if (pollTimer) { clearTimeout(pollTimer); pollTimer = null; }
    if (thinkingTimer) { clearInterval(thinkingTimer); thinkingTimer = null; }
  };

  const finish = (chatId: string, cId: string) => {
    if (finished || aborted) return;
    finished = true;
    clearTimers();
    if (!lastTokenUsage && fullAssistantContent.length > 0) {
      const outputTokens = estimateTokens(fullAssistantContent);
      const inputTokens = Math.round(outputTokens * 2);
      lastTokenUsage = { input: inputTokens, output: outputTokens, total: inputTokens + outputTokens };
    }
    console.log('[QueueChat] complete. chatId:', chatId, 'convId:', cId);
    callbacks.onComplete(chatId, cId, lastTokenUsage);
    callbacks.onStatus?.('complete');
  };

  const fail = (err: Error) => {
    if (finished || aborted) return;
    finished = true;
    clearTimers();
    console.error('[QueueChat] error:', err.message);
    callbacks.onError(err);
  };

  const handleEvents = (events: Array<{ event_type: string; data: any; index: number }>, taskStatus: string) => {
    for (const ev of events) {
      if (aborted || finished) return;
      const idx = typeof ev.index === 'number' ? ev.index : sinceIndex;
      sinceIndex = Math.max(sinceIndex, idx + 1);
      gotAnyEvent = true;
      consecutiveErrors = 0;

      const type = ev.event_type;
      const data = ev.data || {};

      if (data.chat_id) lastChatId = data.chat_id;
      if (data.conversation_id) lastConversationId = data.conversation_id;

      if (type === 'conversation.message.delta') {
        const content = data.content;
        if (content) {
          fullAssistantContent += content;
          if (thinkingTimer) { clearInterval(thinkingTimer); thinkingTimer = null; }
          callbacks.onStatus?.('streaming');
          callbacks.onDelta(content);
        }
      } else if (type === 'conversation.message.completed') {
        const msgType = data.type || data.message_type || '';
        if (data.role === 'assistant') {
          callbacks.onMessageComplete?.();
          try {
            const ext = data.ext ? (typeof data.ext === 'string' ? JSON.parse(data.ext) : data.ext) : data.meta_data;
            const inputT = parseInt(ext?.input_tokens || '0') || 0;
            const outputT = parseInt(ext?.output_tokens || '0') || 0;
            const totalT = parseInt(ext?.token || '0') || 0;
            if (totalT > 0 || inputT > 0 || outputT > 0) {
              lastTokenUsage = { input: inputT, output: outputT, total: totalT || (inputT + outputT) };
            }
          } catch {}
        }
        if (msgType === 'function_call') {
          try {
            const tc = typeof data.content === 'string' ? JSON.parse(data.content || '{}') : data.content;
            const name = tc?.function?.name || tc?.name || data.meta_data?.tool_name || 'unknown';
            const args = tc?.function?.arguments || tc?.arguments || '{}';
            if (name && name !== 'unknown') {
              console.log('[QueueChat] tool call:', name);
              callbacks.onStatus?.('tool_running');
              callbacks.onToolCall?.(name, args);
            }
          } catch {}
        } else if (msgType === 'tool_response') {
          const toolName = data.meta_data?.tool_name || '';
          callbacks.onStatus?.('tool_result');
          callbacks.onToolCall?.(toolName, '', data.content || '');
        } else if (msgType === 'answer') {
          if (thinkingTimer) { clearInterval(thinkingTimer); thinkingTimer = null; }
          callbacks.onStatus?.('streaming');
        }
      } else if (type === 'conversation.chat.created' || type === 'conversation.chat.in_progress') {
        if (!fullAssistantContent) callbacks.onStatus?.('thinking');
      } else if (type === 'conversation.chat.failed') {
        fail(new Error(data.last_error?.msg || '聊天处理失败'));
        return;
      }
    }

    if (finished || aborted) return;
    if (taskStatus === 'completed') {
      finish(lastChatId, lastConversationId);
    } else if (taskStatus === 'failed') {
      fail(new Error('聊天处理失败'));
    } else if (taskStatus === 'cancelled') {
      if (gotAnyEvent) finish(lastChatId, lastConversationId);
      else fail(new Error('任务已取消'));
    }
  };

  const poll = async () => {
    if (aborted || finished) return;
    try {
      const resp = await fetch(`${getRuntimeBase()}/chat-queue/events/${taskId}?since=${sinceIndex}`, {
        method: 'GET',
        headers: { Accept: 'application/json' },
      });
      if (aborted || finished) return;
      if (!resp.ok) throw new Error(`events ${resp.status}`);
      const j = await resp.json();
      if (aborted || finished) return;
      consecutiveErrors = 0;
      if (Array.isArray(j.events)) handleEvents(j.events, j.status || '');
      if (!finished && !aborted) {
        const st = j.status;
        if (st === 'completed' || st === 'failed' || st === 'cancelled') return;
        pollTimer = setTimeout(poll, 700);
      }
    } catch (e: any) {
      if (aborted || finished) return;
      consecutiveErrors++;
      reportBaseFailure();
      if (consecutiveErrors >= 8) {
        fail(new Error('网络连接失败，请稍后重试'));
        return;
      }
      pollTimer = setTimeout(poll, consecutiveErrors >= 4 ? 2000 : 900);
    }
  };

  (async () => {
    try {
      thinkingPhase = 0;
      thinkingTimer = setInterval(() => {
        thinkingPhase++;
        if (thinkingPhase === 1) callbacks.onStatus?.('thinking');
        else if (thinkingPhase === 2) callbacks.onStatus?.('thinking_deep');
        else if (thinkingPhase >= 3) callbacks.onStatus?.('thinking_long');
      }, 12000);
      callbacks.onStatus?.('thinking');

      const submitBody: Record<string, any> = {
        bot_id: body.bot_id,
        user_id: body.user_id,
        conversation_id: convId,
        additional_messages: body.additional_messages,
        stream: body.stream !== undefined ? body.stream : true,
        auto_save_history: body.auto_save_history !== undefined ? body.auto_save_history : true,
        mode: 'primary',
        bearer_token: bearerToken,
      };

      const resp = await fetch(`${getRuntimeBase()}/chat-queue/submit`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${bearerToken}` },
        body: JSON.stringify(submitBody),
      });
      if (aborted) return;

      let j: any = {};
      try { j = await resp.json(); } catch {}

      if (!resp.ok) {
        const err: any = new Error(j.error || `提交失败 (${resp.status})`);
        err.status = resp.status;
        err.code = j.code;
        err.balance = j.balance;
        err.cost = j.cost;
        throw err;
      }

      taskId = j.task_id;
      if (!taskId) throw new Error('队列未返回任务ID');
      console.log('[QueueChat] submitted task:', taskId, 'deduped:', !!j.deduped);
      pollTimer = setTimeout(poll, 400);
    } catch (e: any) {
      if (aborted) return;
      if (e?.name === 'AbortError') { fail(new Error('连接已中断')); return; }
      fail(e instanceof Error ? e : new Error(String(e)));
    }
  })();

  return {
    abort: () => {
      aborted = true;
      clearTimers();
    },
  };
}

export function isBotOpenApiEnabled(connectorIds: string[]): boolean {
  return connectorIds.includes('1024');
}
