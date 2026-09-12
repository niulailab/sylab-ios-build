// Simple event system for cross-component communication
type EventCallback = () => void;
const listeners: Map<string, Set<EventCallback>> = new Map();

export function subscribe(event: string, callback: EventCallback): () => void {
  if (!listeners.has(event)) listeners.set(event, new Set());
  listeners.get(event)!.add(callback);
  return () => listeners.get(event)?.delete(callback);
}

export function emit(event: string) {
  listeners.get(event)?.forEach(cb => cb());
}

export const AppEvents = {
  CONVERSATIONS_CHANGED: 'conversations_changed',
};
