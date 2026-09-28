import axios from 'axios';
import { RUNTIME_BASE as API_BASE } from '../config/runtime';

// 定时任务管理：独立 axios，靠 x-session-key 识别真实身份（后端回查 user 表）。
// 不改动共享 client.ts，避免影响聊天链路。
function makeClient(sessionKey: string) {
  return axios.create({
    baseURL: API_BASE,
    timeout: 20000,
    headers: {
      'Content-Type': 'application/json',
      'x-session-key': sessionKey,
    },
  });
}

export interface ScheduledTask {
  task_uuid: string;
  title: string;
  prompt: string;
  freq_text: string;
  next_run_at: string;
  last_status: string;
  run_count: number;
  status: string; // active / paused
}

interface RawEnvelope {
  code: number;
  msg?: string;
  data?: string | any;
}

function unwrap(body: RawEnvelope): any {
  if (!body || (body.code !== 0 && body.code !== 200)) {
    throw new Error(body?.msg || '请求失败');
  }
  // 后端 data 是 JSON 字符串，需要二次解析
  if (typeof body.data === 'string') {
    try {
      return JSON.parse(body.data);
    } catch {
      return body.data;
    }
  }
  return body.data;
}

export const scheduledTasksApi = {
  // 当前用户的全部定时任务（跨会话）
  async list(sessionKey: string): Promise<{ tasks: ScheduledTask[]; count: number }> {
    const res = await makeClient(sessionKey).post('/schedule/list', { scope: 'all' });
    const d = unwrap(res.data);
    return { tasks: d.tasks || [], count: d.count || (d.tasks || []).length };
  },

  // 暂停 / 恢复
  async toggle(sessionKey: string, taskUuid: string, action: 'pause' | 'resume'): Promise<string> {
    const res = await makeClient(sessionKey).post('/schedule/toggle', {
      task_uuid: taskUuid,
      action,
    });
    return unwrap(res.data)?.summary || '';
  },

  // 删除
  async remove(sessionKey: string, taskUuid: string): Promise<string> {
    const res = await makeClient(sessionKey).post('/schedule/delete', {
      task_uuid: taskUuid,
    });
    return unwrap(res.data)?.summary || '';
  },
};
