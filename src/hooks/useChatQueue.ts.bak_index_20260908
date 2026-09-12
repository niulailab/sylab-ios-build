import { useEffect, useRef, useCallback } from 'react';
import { AppState, AppStateStatus, Platform } from 'react-native';
import { chatQueueApi } from '../api/chatQueue';
import { useChatStore } from '../store/chat';

interface ActiveTask {
  taskId: string;
  conversationId: string;
  lastEventIndex: number;
  isStreaming: boolean;
}

const STORAGE_KEY = 'sylab_active_queue_task';

// Persist task to localStorage so it survives component unmount
function persistTask(task: ActiveTask | null) {
  try {
    if (Platform.OS !== 'web') return;
    if (task) {
      // Use conversation-specific key to prevent cross-conversation leakage
      const key = STORAGE_KEY + '_' + task.conversationId;
      localStorage.setItem(key, JSON.stringify(task));
    } else {
      // Clear all task keys (we don't know which conversation)
      const keysToRemove: string[] = [];
      for (let i = 0; i < localStorage.length; i++) {
        const k = localStorage.key(i);
        if (k && k.startsWith(STORAGE_KEY)) keysToRemove.push(k);
      }
      keysToRemove.forEach(k => localStorage.removeItem(k));
    }
  } catch (e) {
    console.warn('[ChatQueue] Failed to persist task:', e);
  }
}

function loadPersistedTask(conversationId?: string): ActiveTask | null {
  try {
    if (Platform.OS !== 'web') return null;
    if (conversationId) {
      // Load task for specific conversation only
      const raw = localStorage.getItem(STORAGE_KEY + '_' + conversationId);
      if (raw) return JSON.parse(raw);
      return null;
    }
    // Fallback: scan all keys
    for (let i = 0; i < localStorage.length; i++) {
      const k = localStorage.key(i);
      if (k && k.startsWith(STORAGE_KEY)) {
        const raw = localStorage.getItem(k);
        if (raw) return JSON.parse(raw);
      }
    }
  } catch (e) {
    console.warn('[ChatQueue] Failed to load persisted task:', e);
  }
  return null;
}

export function useChatQueue(conversationId?: string) {
  const activeTaskRef = useRef<ActiveTask | null>(null);
  const appStateRef = useRef<AppStateStatus>(AppState.currentState);
  const pollingTimerRef = useRef<NodeJS.Timeout | null>(null);
  const reconnectTimerRef = useRef<NodeJS.Timeout | null>(null);
  const isReconnectingRef = useRef(false);

  // Cleanup all timers
  const clearTimers = useCallback(() => {
    if (pollingTimerRef.current) {
      clearTimeout(pollingTimerRef.current);
      pollingTimerRef.current = null;
    }
    if (reconnectTimerRef.current) {
      clearTimeout(reconnectTimerRef.current);
      reconnectTimerRef.current = null;
    }
  }, []);

  // Register active task (called when sending a message)
  const registerTask = useCallback((taskId: string, conversationId: string) => {
    const task: ActiveTask = { taskId, conversationId, lastEventIndex: 0, isStreaming: true };
    activeTaskRef.current = task;
    persistTask(task);
  }, []);

  // Clear active task (called when streaming completes normally)
  const clearTask = useCallback(() => {
    activeTaskRef.current = null;
    persistTask(null);
    clearTimers();
  }, [clearTimers]);

  // Get active task (for recovery after remount)
  const getActiveTask = useCallback((convId?: string): ActiveTask | null => {
    const refTask = activeTaskRef.current;
    if (refTask) {
      // If conversationId specified, only return if it matches
      if (convId && refTask.conversationId !== convId) return null;
      return refTask;
    }
    return loadPersistedTask(convId);
  }, []);

  // Polling fallback for when SSE reconnect fails
  const pollForCompletion = useCallback(async (taskId: string) => {
    const poll = async () => {
      const task = activeTaskRef.current;
      if (!task || task.taskId !== taskId) return;
      // Don't poll if we're on a different conversation
      if (conversationId && task.conversationId !== conversationId) return;

      try {
        const status = await chatQueueApi.getStatus(taskId);
        if (status.status === 'completed') {
          const { events } = await chatQueueApi.getEvents(taskId, task.lastEventIndex);
          for (const event of events) {
            task.lastEventIndex = event.index + 1;
            if (event.event_type === 'conversation.message.delta' && event.data?.content) {
              useChatStore.getState().appendDelta(event.data.content);
            }
          }
          useChatStore.getState().finishStreaming(status.chat_id || `msg_${Date.now()}`);
          activeTaskRef.current = null;
          persistTask(null);
        } else if (status.status === 'failed') {
          useChatStore.getState().setError(status.error || 'Task failed');
          useChatStore.getState().finishStreaming(`msg_${Date.now()}`);
          activeTaskRef.current = null;
          persistTask(null);
        } else {
          // Still processing, get new events
          const { events } = await chatQueueApi.getEvents(taskId, task.lastEventIndex);
          for (const event of events) {
            task.lastEventIndex = event.index + 1;
            if (event.event_type === 'conversation.message.delta' && event.data?.content) {
              useChatStore.getState().appendDelta(event.data.content);
            }
          }
          // Continue polling - store timer ref for cleanup
          pollingTimerRef.current = setTimeout(poll, 3000);
        }
      } catch (e) {
        console.error('[ChatQueue] Poll error:', e);
        pollingTimerRef.current = setTimeout(poll, 5000);
      }
    };

    pollingTimerRef.current = setTimeout(poll, 3000);
  }, [conversationId]);

  // Handle reconnect after app comes to foreground - with debounce
  const handleReconnect = useCallback(async () => {
    // Prevent concurrent reconnect attempts
    if (isReconnectingRef.current) return;

    const task = getActiveTask(conversationId);
    if (!task || !task.isStreaming) return;
    // Only proceed if this task belongs to the current conversation
    if (conversationId && task.conversationId !== conversationId) return;

    isReconnectingRef.current = true;
    // Restore to ref if needed
    activeTaskRef.current = task;

    console.log('[ChatQueue] Reconnecting to task:', task.taskId);

    try {
      const status = await chatQueueApi.getStatus(task.taskId);

      if (status.status === 'completed') {
        console.log('[ChatQueue] Task completed while away, fetching events');
        const { events } = await chatQueueApi.getEvents(task.taskId, task.lastEventIndex);

        for (const event of events) {
          task.lastEventIndex = event.index + 1;
          if (event.event_type === 'conversation.message.delta' && event.data?.content) {
            useChatStore.getState().appendDelta(event.data.content);
          }
        }

        const chatId = status.chat_id || `msg_${Date.now()}`;
        useChatStore.getState().finishStreaming(chatId);
        activeTaskRef.current = null;
        persistTask(null);

      } else if (status.status === 'processing') {
        console.log('[ChatQueue] Task still processing, reconnecting stream');
        chatQueueApi.connectStream(task.taskId, {
          onDelta: (text) => useChatStore.getState().appendDelta(text),
          onComplete: (chatId) => {
            useChatStore.getState().finishStreaming(chatId || `msg_${Date.now()}`);
            activeTaskRef.current = null;
            persistTask(null);
          },
          onError: (err) => {
            console.error('[ChatQueue] Stream reconnect error:', err);
            pollForCompletion(task.taskId);
          },
        });

      } else if (status.status === 'failed') {
        console.error('[ChatQueue] Task failed:', status.error);
        useChatStore.getState().setError(status.error || 'Background task failed');
        useChatStore.getState().finishStreaming(`msg_${Date.now()}`);
        activeTaskRef.current = null;
        persistTask(null);
      }
    } catch (e) {
      console.error('[ChatQueue] Reconnect failed:', e);
      pollForCompletion(task.taskId);
    } finally {
      // Debounce: allow reconnect again after 2 seconds
      reconnectTimerRef.current = setTimeout(() => {
        isReconnectingRef.current = false;
      }, 2000);
    }
  }, [pollForCompletion, getActiveTask, conversationId]);

  // Listen for AppState changes (mobile) and page visibility changes (web)
  useEffect(() => {
    // Mobile: AppState listener
    const subscription = AppState.addEventListener('change', (nextState) => {
      const prevState = appStateRef.current;
      appStateRef.current = nextState;

      if (nextState === 'active' && (prevState === 'background' || prevState === 'inactive')) {
        console.log('[ChatQueue] App foregrounded, checking active tasks');
        handleReconnect();
      }

      if (nextState === 'background' || nextState === 'inactive') {
        console.log('[ChatQueue] App backgrounded, task will continue on server');
      }
    });

    // Web: visibilitychange listener
    let webHandler: (() => void) | null = null;
    if (Platform.OS === 'web') {
      webHandler = () => {
        if (document.visibilityState === 'visible') {
          console.log('[ChatQueue] Page became visible, checking active tasks');
          handleReconnect();
        }
      };
      document.addEventListener('visibilitychange', webHandler);
    }

    return () => {
      subscription.remove();
      if (webHandler && Platform.OS === 'web') {
        document.removeEventListener('visibilitychange', webHandler);
      }
      // Clean up all timers on unmount
      clearTimers();
      isReconnectingRef.current = false;
    };
  }, [handleReconnect, clearTimers]);

  return { registerTask, clearTask, activeTaskRef, getActiveTask };
}
