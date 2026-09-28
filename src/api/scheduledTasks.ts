import { webApiClient } from './client';

// 定时任务管理：复用共享 webApiClient（authMode='session'），
// 原生 Cookie 容器里的 session_key 会自动随请求带上；同时兼容 x-session-key。
// 这样旧版登录态（本地未存 session_key 字符串、但 Cookie 仍有效）也能正常识别身份。

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

// webApiClient 的响应拦截器已解包 {code,data}，这里拿到的 res.data 即后端 data，
// 后端 data 是 JSON 字符串，需要二次解析。
function parseData(raw: any): any {
  if (typeof raw === 'string') {
    try {
      return JSON.parse(raw);
    } catch {
      return raw;
    }
  }
  return raw;
}

export const scheduledTasksApi = {
  // 当前用户的全部定时任务（跨会话）
  async list(): Promise<{ tasks: ScheduledTask[]; count: number }> {
    const res = await webApiClient.post('/schedule/list', { scope: 'all' });
    const d = parseData(res.data);
    return { tasks: d.tasks || [], count: d.count || (d.tasks || []).length };
  },

  // 暂停 / 恢复
  async toggle(taskUuid: string, action: 'pause' | 'resume'): Promise<string> {
    const res = await webApiClient.post('/schedule/toggle', {
      task_uuid: taskUuid,
      action,
    });
    return parseData(res.data)?.summary || '';
  },

  // 删除
  async remove(taskUuid: string): Promise<string> {
    const res = await webApiClient.post('/schedule/delete', {
      task_uuid: taskUuid,
    });
    return parseData(res.data)?.summary || '';
  },
};
