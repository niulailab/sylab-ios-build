/**
 * queueTaskManager.ts
 * 全局聊天队列任务管理器（模块级单例，生命周期独立于聊天页组件）。
 *
 * 设计目标（对齐扣子体验）：
 * - SSE 连接全程由本管理器持有：离开聊天页 / 切后台 / 杀掉 APP 重开，
 *   服务端任务持续跑，APP 存活期间自动重连续流；冷启动从持久化存储恢复
 *   任务游标并 backfill 全部历史，再从游标续 live 流。
 * - 聊天页 attach/detach：进入会话即灌入已生成内容快照（思考状态/工具步骤/
 *   已生成正文），离开不中断、不清理。
 * - 全局 finalize：消息落库（saveChatLog + Coze 历史备份）、会话自动命名、
 *   待传附件上传，无论页面是否挂载都执行。
 * - 视频生成轮询同样全局持有，状态变更广播给任意页面。
 */
import { AppState, Platform } from 'react-native';
import AsyncStorage from '@react-native-async-storage/async-storage';
import NetInfo from '@react-native-community/netinfo';
import { chatQueueApi } from '../api/chatQueue';
import type { QueueSubmitRequest } from '../api/chatQueue';
import { useChatStore } from '../store/chat';
import { chatApi } from '../api/chat';
import { filesApi } from '../api/files';
import { getPendingFiles, clearPendingFiles } from '../components/ChatInput';
import { getToolLabel } from '../components/TypingIndicator';
import { AppEvents, emit } from '../utils/events';

const STORAGE_KEY = 'sylab_qtask_';

export interface QueueToolCall {
  id: string;
  name: string;
  arguments: string;
  result?: string;
}

export interface VideoTaskInfo {
  taskId: string;
  convId: string;
  msgId: string;
  status: string;
  progress: number;
  url: string;
}

interface QueueTask {
  taskId: string;
  conversationId: string;
  userContent: string;
  lastEventIndex: number;
  isStreaming: boolean;
  status: string;
  content: string; // 累计 AI 回复正文（已 stripEmoji）
  tools: QueueToolCall[];
  streamConn: { abort: () => void } | null;
  seenIndexes: Set<number>;
  reconnectAttempts: number;
  reconnectTimer: ReturnType<typeof setTimeout> | null;
  persistTimer: ReturnType<typeof setTimeout> | null;
  startedAt: number;
}

export interface PageCallbacks {
  onComplete?: (chatId: string, convId: string) => void;
  onError?: (msg: string, status?: number, code?: string) => void;
  // [patch 2026-09-09] 任务终态但本地拿不到正文（流断/中转缓存过期）时，
  // 通知聊天页重新拉取服务端会话历史——结果永久在历史里，不弹"过期"
  onReloadHistory?: (convId: string) => void;
}

const stripEmoji = (text: string): string => {
  if (!text) return text;
  return text.replace(/[\u{1F300}-\u{1F9FF}]|[\u{2600}-\u{26FF}]|[\u{2700}-\u{27BF}]|[\u{1F000}-\u{1F02F}]|[\u{1F0A0}-\u{1F0FF}]|[\u{1F100}-\u{1F1FF}]|[\u{1F200}-\u{1F2FF}]|[\u{1F600}-\u{1F64F}]|[\u{1F680}-\u{1F6FF}]|[\u{1F900}-\u{1F9FF}]|\u{FE0F}|\u{200D}/gu, '');
};

class QueueTaskManagerImpl {
  tasks = new Map<string, QueueTask>();
  attachedConvId: string | null = null;
  pageCallbacks: PageCallbacks | null = null;
  videoTasks = new Map<string, VideoTaskInfo>();
  videoTimers = new Map<string, ReturnType<typeof setInterval>>();
  initialized = false;

  // ---------------- persistence ----------------
  private persistKey(convId: string) {
    return STORAGE_KEY + convId;
  }

  persist(task: QueueTask) {
    try {
      const data = {
        taskId: task.taskId,
        conversationId: task.conversationId,
        userContent: task.userContent,
        lastEventIndex: task.lastEventIndex,
        isStreaming: task.isStreaming,
        status: task.status,
        savedAt: Date.now(),
      };
      const raw = JSON.stringify(data);
      if (Platform.OS === 'web') {
        localStorage.setItem(this.persistKey(task.conversationId), raw);
      } else {
        AsyncStorage.setItem(this.persistKey(task.conversationId), raw).catch(() => {});
      }
    } catch (e) {
      console.warn('[QueueMgr] persist failed:', e);
    }
  }

  private schedulePersist(task: QueueTask) {
    if (task.persistTimer) return;
    task.persistTimer = setTimeout(() => {
      task.persistTimer = null;
      if (this.tasks.has(task.taskId)) this.persist(task);
    }, 2000);
  }

  private removePersist(convId: string) {
    try {
      if (Platform.OS === 'web') {
        localStorage.removeItem(this.persistKey(convId));
      } else {
        AsyncStorage.removeItem(this.persistKey(convId)).catch(() => {});
      }
    } catch (e) {}
  }

  private async loadAllPersisted(): Promise<Array<Record<string, any>>> {
    try {
      if (Platform.OS === 'web') {
        const out: Array<Record<string, any>> = [];
        for (let i = 0; i < localStorage.length; i++) {
          const k = localStorage.key(i);
          if (k && k.startsWith(STORAGE_KEY)) {
            try { out.push(JSON.parse(localStorage.getItem(k) || '{}')); } catch (e) {}
          }
        }
        return out;
      }
      const all = (await AsyncStorage.getAllKeys()) as string[];
      const keys = all.filter((k) => k.startsWith(STORAGE_KEY));
      const out: Array<Record<string, any>> = [];
      for (const k of keys) {
        const raw = await AsyncStorage.getItem(k);
        if (raw) { try { out.push(JSON.parse(raw)); } catch (e) {} }
      }
      return out;
    } catch (e) {
      return [];
    }
  }

  // ---------------- lifecycle ----------------
  async init() {
    if (this.initialized) return;
    this.initialized = true;

    // App 回前台 / web 标签页重新可见 / 网络恢复：检查并重连所有活跃任务
    AppState.addEventListener('change', (state) => {
      if (state === 'active') this.reconnectAll();
    });
    if (Platform.OS === 'web' && typeof document !== 'undefined') {
      document.addEventListener('visibilitychange', () => {
        if (document.visibilityState === 'visible') this.reconnectAll();
      });
    }
    try {
      NetInfo.addEventListener((s) => {
        if (s.isConnected) this.reconnectAll();
      });
    } catch (e) {}

    // 冷启动恢复持久化任务
    const persisted = await this.loadAllPersisted();
    for (const p of persisted) {
      if (!p || !p.taskId) continue;
      const task = this.buildTaskFromPersisted(p);
      this.tasks.set(task.taskId, task);
      try {
        const st = await chatQueueApi.getStatus(task.taskId);
        if (st.status === 'processing' || st.status === 'pending') {
          task.conversationId = task.conversationId || st.conversation_id || '';
          // 新进程内存为空：从 0 全量 backfill 历史内容
          await this.backfill(task, 0);
          this.connectStream(task);
          emit(AppEvents.CHAT_TASK_UPDATED);
        } else {
          // [patch 2026-09-09] completed/failed/cancelled/过期：结果已在 Coze 历史，
          // 静默清理本地中转记录（不恢复流式态，不弹任何提示）
          this.removeTask(task);
        }
      } catch (e: any) {
        const msg = String(e?.message || '');
        if (msg.includes('404')) {
          // 中转记录不存在：结果在历史里，直接清理
          this.removeTask(task);
          return;
        }
        // 网络暂不可用：保留任务并尝试连接（失败会进入自动重连循环，有上限）
        console.warn('[QueueMgr] recover status check failed, will retry:', task.taskId);
        this.connectStream(task);
        emit(AppEvents.CHAT_TASK_UPDATED);
      }
    }
  }

  private buildTaskFromPersisted(p: Record<string, any>): QueueTask {
    return {
      taskId: p.taskId,
      conversationId: p.conversationId || '',
      userContent: p.userContent || '',
      lastEventIndex: 0,
      isStreaming: true,
      status: '正在思考理解…',
      content: '',
      tools: [],
      streamConn: null,
      seenIndexes: new Set<number>(),
      reconnectAttempts: 0,
      reconnectTimer: null,
      persistTimer: null,
      startedAt: p.savedAt || Date.now(),
    };
  }

  // ---------------- task start ----------------
  async startTask(req: QueueSubmitRequest, bearerToken: string, userContent: string) {
    const convId = req.conversation_id || '';
    // 只要本会话有活跃任务/页面处于本会话就视为已 attach：
    // 新会话 router.replace 竞态下 attachedConvId 可能仍是旧路由 id，这里用任务本身兜底
    const attached = this.isAttachedConv(convId)
      || this.attachedConvId != null && this.getTaskByConv(this.attachedConvId) == null
      || this.attachedConvId === null && this.pageCallbacks != null;
    if (attached) {
      // 把 attach 目标对齐到真实 convId，防止后续 delta/tool 事件因 id 不匹配而丢弃
      if (this.attachedConvId !== convId) this.attachedConvId = convId;
      useChatStore.getState().startStreaming();
    }
    let resp: { task_id: string; status: string };
    try {
      resp = await chatQueueApi.submit(req, bearerToken);
    } catch (e: any) {
      console.error('[QueueMgr] submit failed:', e?.message || e, 'status=', e?.status, 'code=', e?.code);
      if (attached) {
        // 401 未登录 / 402 积分不足：透出服务端真实文案，页面侧负责跳登录/引导充值
        const friendly = (e?.status === 401 || e?.status === 402)
          ? (e?.message || '发送失败')
          : '发送失败，请重试';
        useChatStore.getState().setError(friendly);
        try { this.pageCallbacks?.onError?.(friendly, e?.status, e?.code); } catch (cbErr) {}
      }
      return;
    }
    const task: QueueTask = {
      taskId: resp.task_id,
      conversationId: convId,
      userContent,
      lastEventIndex: 0,
      isStreaming: true,
      status: '正在思考理解…',
      content: '',
      tools: [],
      streamConn: null,
      seenIndexes: new Set<number>(),
      reconnectAttempts: 0,
      reconnectTimer: null,
      persistTimer: null,
      startedAt: Date.now(),
    };
    this.tasks.set(task.taskId, task);
    this.persist(task);
    emit(AppEvents.CHAT_TASK_UPDATED);
    console.log('[QueueMgr] task started:', task.taskId, 'conv:', convId);
    this.connectStream(task);
  }

  // ---------------- streaming ----------------
  private connectStream(task: QueueTask) {
    if (task.streamConn) {
      try { task.streamConn.abort(); } catch (e) {}
      task.streamConn = null;
    }
    let frameIdx = -1;
    const conn = chatQueueApi.connectStream(
      task.taskId,
      {
        onDelta: (text) => {
          // 去重闸门：同一帧 onEventIndex 先于 onDelta 到达
          if (frameIdx >= 0 && task.seenIndexes.has(frameIdx)) return;
          if (frameIdx >= 0) task.seenIndexes.add(frameIdx);
          const clean = stripEmoji(text);
          task.content += clean;
          task.status = '正在输入回复…';
          if (this.isAttached(task)) {
            useChatStore.getState().appendDelta(clean);
          }
          this.schedulePersist(task);
        },
        onToolCall: (name, args, result) => {
          this.handleToolEvent(task, name, args, result);
        },
        onComplete: (chatId, convId) => {
          task.streamConn = null;
          this.finalizeComplete(task, chatId || '', convId || task.conversationId);
        },
        onError: (err) => {
          console.error('[QueueMgr] stream error:', err?.message || err);
          task.streamConn = null;
          this.scheduleReconnect(task);
        },
        onEventIndex: (idx) => {
          frameIdx = idx;
          task.lastEventIndex = Math.max(task.lastEventIndex, idx + 1);
          this.schedulePersist(task);
        },
      },
      task.lastEventIndex
    );
    task.streamConn = conn;
    task.reconnectAttempts = 0;
  }

  private handleToolEvent(task: QueueTask, name: string, args: string, result?: string) {
    if (result !== undefined) {
      const label = getToolLabel(name || 'tool');
      // 先按名字匹配；meta_data.tool_name 偶发为空时回退到最后一个未完成步骤
      let idx = name ? task.tools.findIndex((t) => t.name === name && !t.result) : -1;
      if (idx < 0) {
        for (let i = task.tools.length - 1; i >= 0; i--) {
          if (!task.tools[i].result) { idx = i; break; }
        }
      }
      if (idx >= 0) {
        task.tools[idx] = { ...task.tools[idx], result: result || '' };
      }
      task.status = label + '完成';
      if (this.isAttached(task)) {
        // 空名字也透传给 store（store 有同样的回退标记逻辑），保证 ✓ 能打出来
        useChatStore.getState().appendToolCall(name || task.tools[idx]?.name || '', args || '', result);
      }
      // 视频生成任务：从工具结果中抓 task_id 并全局轮询
      if (name === 'video_generate' || name === 'generate_video') {
        try {
          const parsed = typeof result === 'string' ? JSON.parse(result) : result;
          const rd = typeof parsed.data === 'string' ? JSON.parse(parsed.data || '{}') : parsed.data || parsed;
          const tid = rd.task_id || rd.taskId;
          if (tid && String(tid).startsWith('task_')) {
            this.startVideoPolling(String(tid), task.conversationId);
          }
        } catch (e) {}
      }
    } else {
      if (!name) return;
      const isDup = args ? task.tools.some((t) => t.name === name && t.arguments === args) : false;
      if (isDup) return;
      task.tools.push({
        id: 'tc_' + Date.now() + '_' + Math.random().toString(36).slice(2, 7),
        name,
        arguments: args || '',
      });
      task.status = '正在' + getToolLabel(name) + '…';
      if (this.isAttached(task)) {
        useChatStore.getState().appendToolCall(name, args || '');
      }
    }
    this.schedulePersist(task);
    emit(AppEvents.CHAT_TASK_UPDATED);
  }

  private async backfill(task: QueueTask, since: number) {
    try {
      const { events } = await chatQueueApi.getEvents(task.taskId, since);
      for (const ev of events) {
        if (task.seenIndexes.has(ev.index)) continue;
        task.seenIndexes.add(ev.index);
        task.lastEventIndex = Math.max(task.lastEventIndex, ev.index + 1);
        if (ev.event_type === 'conversation.message.delta' && ev.data?.content) {
          const clean = stripEmoji(ev.data.content);
          task.content += clean;
          task.status = '正在输入回复…';
          if (this.isAttached(task)) {
            useChatStore.getState().appendDelta(clean);
          }
        } else if (ev.event_type === 'conversation.message.completed') {
          const data = ev.data || {};
          if (data.type === 'tool_response') {
            const tname = data.meta_data?.tool_name || '';
            // 空名字也交给 handleToolEvent 统一处理（内部回退标记未完成步骤）
            this.handleToolEvent(task, tname, '', data.content || '');
          } else if (data.type === 'function_call') {
            try {
              const tc = typeof data.content === 'string' ? JSON.parse(data.content || '{}') : data.content;
              const fn = tc.function || tc;
              if (fn?.name) this.handleToolEvent(task, fn.name, fn.arguments || '');
            } catch (e) {}
          }
        }
      }
      this.schedulePersist(task);
      emit(AppEvents.CHAT_TASK_UPDATED);
    } catch (e) {
      console.warn('[QueueMgr] backfill failed:', e);
    }
  }

  private scheduleReconnect(task: QueueTask) {
    if (!task.isStreaming || task.reconnectTimer) return;
    task.reconnectAttempts++;
    const delay = Math.min(1000 * Math.pow(2, Math.min(task.reconnectAttempts, 5)), 30000);
    console.log('[QueueMgr] reconnect in', delay, 'ms for', task.taskId, 'attempt', task.reconnectAttempts);
    task.reconnectTimer = setTimeout(async () => {
      task.reconnectTimer = null;
      if (!task.isStreaming) return;
      try {
        const st = await chatQueueApi.getStatus(task.taskId);
        if (st.status === 'completed' || st.status === 'cancelled') {
          // [patch 2026-09-09] 终态：补拉正文后静默收尾+刷新历史（结果以服务端历史为准）
          await this.backfill(task, task.lastEventIndex).catch(() => {});
          if (task.isStreaming) this.silentFinish(task, st.conversation_id || task.conversationId);
          return;
        }
        if (st.status === 'failed') {
          try { this.pageCallbacks?.onReloadHistory?.(task.conversationId); } catch (e) {}
          this.finalizeFail(task, st.error || '任务执行失败，请重试');
          return;
        }
        // pending / processing：补拉漏掉的事件，再从游标续 live 流
        await this.backfill(task, task.lastEventIndex);
        this.connectStream(task);
      } catch (e: any) {
        // [patch 2026-09-09] 404=中转记录不存在 → 结果在历史，静默收尾；
        // 重试超过 20 次（约 8 分钟）也强制静默收尾，杜绝永久转圈
        const msg = String(e?.message || '');
        if (msg.includes('404')) {
          this.silentFinish(task, task.conversationId);
          return;
        }
        if (task.reconnectAttempts >= 20) {
          this.silentFinish(task, task.conversationId);
          return;
        }
        // 网络仍不通：继续退避重试
        this.scheduleReconnect(task);
      }
    }, delay);
  }

  reconnectAll() {
    for (const task of Array.from(this.tasks.values())) {
      if (!task.isStreaming) continue;
      if (!task.streamConn && !task.reconnectTimer) {
        this.scheduleReconnect(task);
      }
    }
  }

  // ---------------- finalize ----------------
  private finalizeComplete(task: QueueTask, chatId: string, convId: string) {
    if (!task.isStreaming) return;
    const content = stripEmoji(task.content || '');
    const finalConvId = convId || task.conversationId;

    // [patch 2026-09-10] 流终态但本地正文为空（任务被服务端去重取消/结果未在流中到达）：
    // 不得在屏幕上留下空气泡——静默结束转圈并刷新服务端会话历史（原任务结果已永久落库）。
    // 典型场景：重发同一句话时服务端去重命中，新任务被 cancel、无任何 delta/done 只有空结束。
    if (!content) {
      console.warn('[QueueMgr] stream finished with empty content, fallback to silent reload:', task.taskId);
      this.silentFinish(task, finalConvId);
      return;
    }

    task.isStreaming = false;
    const finalChatId = chatId || `msg_${Date.now()}`;

    if (this.isAttached(task)) {
      const store = useChatStore.getState();
      const savedToolCalls = store.toolCalls;
      useChatStore.setState({
        isStreaming: false,
        streamingContent: '',
        streamingMessageId: null,
        activityStatus: '',
        generatingType: null,
        error: null,
      });
      if (content) {
        const aiMsg: any = {
          id: finalChatId,
          conversation_id: finalConvId,
          role: 'assistant',
          type: 'text',
          content,
          content_type: 'markdown',
          created_at: String(Date.now()),
          updated_at: String(Date.now()),
        };
        if (savedToolCalls.length > 0) {
          aiMsg.tool_calls = savedToolCalls.map((tc) => ({
            id: tc.id,
            type: 'function',
            function: { name: tc.name, arguments: tc.arguments || '{}' },
          }));
        }
        const cur = useChatStore.getState().messages;
        const exists = cur.some(
          (m) => m.id === finalChatId || (m.role === 'assistant' && m.content === content)
        );
        if (!exists) useChatStore.getState().setMessages([...cur, aiMsg]);
      }
    }

    // 视频任务：正文里可能含 task_id；已在轮询的补上 msgId
    this.detectVideoTasks(content, finalConvId, finalChatId);
    this.associateVideoMsgId(finalConvId, finalChatId);

    // 全局收尾（落库/命名/附件），页面是否挂载都执行
    this.globalFinalize(task, content, finalConvId);

    if (this.isAttached(task)) {
      try { this.pageCallbacks?.onComplete?.(finalChatId, finalConvId); } catch (e) {}
    }

    this.removeTask(task);
  }

  private finalizeFail(task: QueueTask, msg: string) {
    if (!task.isStreaming) return;
    task.isStreaming = false;
    console.warn('[QueueMgr] task failed:', task.taskId, msg);
    if (this.isAttached(task)) {
      useChatStore.getState().setError(msg || '任务失败');
      useChatStore.getState().finishStreaming(`msg_${Date.now()}`);
      try { this.pageCallbacks?.onError?.(msg || '任务失败'); } catch (e) {}
    }
    this.removeTask(task);
  }

  // [patch 2026-09-09] 静默收尾：结束转圈、清理任务，不弹任何错误；
  // 结果以服务端会话历史为准，通知聊天页刷新历史。
  private silentFinish(task: QueueTask, convId: string) {
    task.isStreaming = false;
    if (this.isAttached(task)) {
      try { useChatStore.getState().clearStreaming(); } catch (e) {}
      try { this.pageCallbacks?.onReloadHistory?.(convId || task.conversationId); } catch (e) {}
    }
    this.removeTask(task);
  }

  private globalFinalize(task: QueueTask, content: string, convId: string) {
    if (!convId) return;
    try {
      const saveMessages: Array<{ role: string; content: string; created_at: string }> = [];
      if (task.userContent) {
        saveMessages.push({ role: 'user', content: task.userContent, created_at: String(task.startedAt || Date.now()) });
      }
      if (content) {
        saveMessages.push({ role: 'assistant', content, created_at: String(Date.now()) });
      }
      if (saveMessages.length > 0) {
        filesApi.saveChatLog(convId, saveMessages).catch((e) => console.warn('[QueueMgr] saveChatLog failed:', e));
      }
      // 3s 后从 Coze 拉完整历史备份覆盖
      setTimeout(async () => {
        try {
          const msgResult = await chatApi.getMessages(convId, { page_num: 1, page_size: 50 });
          const items = (msgResult.items || []).filter((m: any) => m.role === 'user' || m.role === 'assistant');
          if (items.length > 0) {
            await filesApi.saveChatLog(
              convId,
              items.map((m: any) => ({ role: m.role, content: m.content || '', created_at: m.created_at || String(Date.now()) }))
            );
          }
        } catch (e) {}
      }, 3000);
      // 会话自动命名（取首条用户消息前 30 字）
      if (task.userContent) {
        const name = task.userContent
          .replace(/<[^>]+>/g, '')
          .replace(/[#*`>\[\]()!！？\n]/g, ' ')
          .trim()
          .substring(0, 30);
        if (name) chatApi.updateConversation(convId, { name }).catch(() => {});
      }
      // 待传附件（新会话发送时 convId 未定，先暂存）
      try {
        const pending = getPendingFiles();
        if (pending.length > 0) {
          for (const pf of pending) {
            fetch('https://s.symsgf.xyz/project-files/api/files/upload', {
              method: 'POST',
              headers: {
                'X-Conversation-Id': convId,
                'X-File-Name': pf.name,
                'Content-Type': pf.type,
              },
              body: pf.blob,
            }).catch(() => {});
          }
          clearPendingFiles();
        }
      } catch (e) {}
    } catch (e) {
      console.warn('[QueueMgr] globalFinalize error:', e);
    }
  }

  private removeTask(task: QueueTask) {
    if (task.streamConn) { try { task.streamConn.abort(); } catch (e) {} task.streamConn = null; }
    if (task.reconnectTimer) { clearTimeout(task.reconnectTimer); task.reconnectTimer = null; }
    if (task.persistTimer) { clearTimeout(task.persistTimer); task.persistTimer = null; }
    this.tasks.delete(task.taskId);
    this.removePersist(task.conversationId);
    emit(AppEvents.CHAT_TASK_UPDATED);
  }

  // ---------------- page attach/detach ----------------
  attach(convId: string, callbacks: PageCallbacks) {
    this.attachedConvId = convId;
    this.pageCallbacks = callbacks;
    const task = this.getTaskByConv(convId);
    if (task && task.isStreaming) {
      // 灌入快照：重置流式态 → 工具步骤 → 已生成正文 → 当前阶段文案
      const store = useChatStore.getState();
      store.startStreaming();
      if (task.tools.length > 0) {
        useChatStore.setState({
          toolCalls: task.tools.map((t) => ({ id: t.id, name: t.name, arguments: t.arguments, result: t.result })),
        });
      }
      if (task.content) {
        useChatStore.getState().appendDelta(task.content);
      }
      useChatStore.getState().setActivityStatus(task.status || '正在思考理解…');
      console.log('[QueueMgr] attach conv', convId, 'resumed task', task.taskId, 'content len:', task.content.length);
      // [patch 2026-09-09] 进入页面立即核对服务端真实状态：
      // 任务可能早已结束而本地连接失活，不核对会永久转圈
      this.verifyTaskOnAttach(task);
    }
  }

  // [patch 2026-09-09] attach 时权威状态核对：终态静默收尾+刷新历史，活态但连接失活则重连
  private verifyTaskOnAttach(task: QueueTask) {
    (async () => {
      try {
        const st = await chatQueueApi.getStatus(task.taskId);
        if (!this.tasks.has(task.taskId) || !task.isStreaming) return;
        if (st.status === 'failed') {
          // 真实失败：给可重试提示（结果可能在历史里，先刷新历史）
          try { this.pageCallbacks?.onReloadHistory?.(task.conversationId); } catch (e) {}
          this.finalizeFail(task, st.error || '任务执行失败，请重试');
          return;
        }
        if (st.status === 'cancelled' || st.status === 'completed') {
          // 完成/取消/过期(stale)：结果在服务端会话历史，静默收尾并刷新
          await this.backfill(task, task.lastEventIndex).catch(() => {});
          if (task.isStreaming) this.silentFinish(task, st.conversation_id || task.conversationId);
          return;
        }
        // pending / processing：连接失活才重连（有活连接不动）
        if (!task.streamConn && !task.reconnectTimer) {
          this.scheduleReconnect(task);
        }
      } catch (e: any) {
        const msg = String(e?.message || '');
        if (msg.includes('404')) {
          // 中转记录不存在：结果在历史里，静默收尾
          this.silentFinish(task, task.conversationId);
          return;
        }
        // 网络暂不通：连接失活时走退避重连（有上限）
        if (task.isStreaming && !task.streamConn && !task.reconnectTimer) {
          this.scheduleReconnect(task);
        }
      }
    })();
  }

  detach(convId: string) {
    if (this.attachedConvId === convId) {
      this.attachedConvId = null;
      this.pageCallbacks = null;
      // 注意：不清理 streaming store、不 abort 流——任务继续在全局跑
    }
  }

  cancelForConv(convId: string) {
    const task = this.getTaskByConv(convId);
    if (task) {
      chatQueueApi.cancel(task.taskId).catch((e) => console.warn('[QueueMgr] cancel failed:', e));
      this.removeTask(task);
    }
    useChatStore.getState().clearStreaming();
  }

  // ---------------- queries ----------------
  getTaskByConv(convId: string): QueueTask | null {
    for (const t of this.tasks.values()) {
      if (t.conversationId === convId && t.isStreaming) return t;
    }
    return null;
  }

  getActiveConversationIds(): string[] {
    return Array.from(this.tasks.values()).filter((t) => t.isStreaming && t.conversationId).map((t) => t.conversationId);
  }

  getVideoTasks(): Map<string, VideoTaskInfo> {
    return this.videoTasks;
  }

  private isAttached(task: QueueTask): boolean {
    return this.attachedConvId != null && this.attachedConvId === task.conversationId;
  }

  private isAttachedConv(convId: string): boolean {
    return this.attachedConvId === convId;
  }

  // ---------------- video polling (global) ----------------
  startVideoPolling(taskId: string, convId: string, msgId: string = '') {
    if (this.videoTasks.has(taskId)) return;
    this.videoTasks.set(taskId, { taskId, convId, msgId, status: 'polling', progress: 0, url: '' });
    emit(AppEvents.CHAT_VIDEO_UPDATED);

    const poll = async () => {
      try {
        const resp = await fetch('https://s.symsgf.xyz/video/status/' + taskId);
        const data = await resp.json();
        const parsed = typeof data.data === 'string' ? JSON.parse(data.data || '{}') : data.data || data;
        const status = parsed.status || 'unknown';
        const url = parsed.video_url || '';
        const progress =
          typeof parsed.progress === 'number' ? parsed.progress : parseInt(String(parsed.progress), 10) || 0;
        const cur = this.videoTasks.get(taskId);
        if (cur) {
          this.videoTasks.set(taskId, { ...cur, status, url, progress });
          emit(AppEvents.CHAT_VIDEO_UPDATED);
          if ((status === 'completed' && url) || status === 'failed') {
            const iv = this.videoTimers.get(taskId);
            if (iv) { clearInterval(iv); this.videoTimers.delete(taskId); }
          }
        }
      } catch (e) {}
    };

    poll();
    const iv = setInterval(poll, 10000);
    this.videoTimers.set(taskId, iv);
    // 5 分钟超时
    setTimeout(() => {
      const t = this.videoTimers.get(taskId);
      if (t) { clearInterval(t); this.videoTimers.delete(taskId); }
      const cur = this.videoTasks.get(taskId);
      if (cur && cur.status !== 'completed') {
        this.videoTasks.set(taskId, { ...cur, status: 'timeout' });
        emit(AppEvents.CHAT_VIDEO_UPDATED);
      }
    }, 300000);
  }

  private detectVideoTasks(content: string, convId: string, chatId: string) {
    if (!content) return;
    const patterns = [
      /task_id["\s:]+["']?(task_[A-Za-z0-9]+)["']?/gi,
      /task_(?:id)?["\s:=]+["']?(task_[A-Za-z0-9_]+)["']?/gi,
      /任务ID[：:\s]+\s*(task_[A-Za-z0-9_]+)/gi,
      /\b(task_[A-Za-z0-9]{20,})\b/gi,
    ];
    const ids = new Set<string>();
    for (const p of patterns) {
      let m: RegExpExecArray | null;
      while ((m = p.exec(content)) !== null) ids.add(m[1]);
    }
    for (const tid of ids) this.startVideoPolling(tid, convId, chatId);
  }

  private associateVideoMsgId(convId: string, chatId: string) {
    let changed = false;
    for (const [tid, info] of this.videoTasks) {
      if (info.convId === convId && !info.msgId) {
        this.videoTasks.set(tid, { ...info, msgId: chatId });
        changed = true;
      }
    }
    if (changed) emit(AppEvents.CHAT_VIDEO_UPDATED);
  }
}

export const queueManager = new QueueTaskManagerImpl();
