/**
 * 跨页面「待引用技能」暂存：从技能 Tab / 技能库选中技能后，
 * 进入聊天页时由 ChatInput 读取并一次性消费（读后即清）。
 * 纯新增模块，不影响既有聊天/队列逻辑。
 */
import type { Skill } from '../api/skill';

let current: Skill | null = null;
const listeners = new Set<() => void>();

function emit() {
  listeners.forEach((fn) => fn());
}

export function setPendingSkill(skill: Skill | null) {
  current = skill;
  emit();
}

/** 读取但不移除（组件同步 state 用） */
export function peekPendingSkill(): Skill | null {
  return current;
}

/** 消费：取出并清空，避免进同一聊天页被重复引用 */
export function consumePendingSkill(): Skill | null {
  const v = current;
  current = null;
  emit();
  return v;
}

export function subscribePendingSkill(fn: () => void): () => void {
  listeners.add(fn);
  return () => listeners.delete(fn);
}
