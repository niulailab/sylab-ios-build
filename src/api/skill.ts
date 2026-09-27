/**
 * 技能库模块（独立服务，经 nginx /skill-api 反代到记忆服务 :8900）
 * 存储模型：layer=long_term, category=skill，metadata 存技能专属字段。
 * 该模块纯增量，不修改任何既有 API/渲染逻辑。
 */
import { RUNTIME_BASE } from '../config/runtime';

export interface SkillParam {
  name: string;
  required: boolean;
  desc: string;
  example: string;
}

export interface SkillMeta {
  skill_id: string;
  scope: 'official' | 'private';
  icon: string;
  version: number;
  status: 'active' | string;
  source: 'official' | 'manual' | 'upload' | 'ai_extracted' | string;
  params_schema: SkillParam[];
  trigger?: string;
  tools?: string[];
  call_count?: number;
  success_count?: number;
  est_credits?: [number, number];
  category_label?: string;
}

export interface SkillRecord {
  id: number;
  title: string;
  content: string;
  tags: string[];
  category: string;
  layer: string;
  importance: number;
  metadata: SkillMeta;
  created_at?: string;
}

export interface Skill {
  id: number;
  skillId: string;
  name: string;
  icon: string;
  category: string;
  scope: 'official' | 'private';
  trigger: string;
  tools: string[];
  estCredits: [number, number];
  params: SkillParam[];
  content: string;
  callCount: number;
  successCount: number;
  version: number;
}

function toSkill(m: SkillRecord): Skill {
  const meta = (m.metadata || {}) as SkillMeta;
  return {
    id: m.id,
    skillId: meta.skill_id || `skill-${m.id}`,
    name: m.title,
    icon: meta.icon || '🧩',
    category: meta.category_label || '其它',
    scope: meta.scope || 'private',
    trigger: meta.trigger || '',
    tools: meta.tools || [],
    estCredits: meta.est_credits || [0, 0],
    params: meta.params_schema || [],
    content: m.content || '',
    callCount: meta.call_count || 0,
    successCount: meta.success_count || 0,
    version: meta.version || 1,
  };
}

async function skillFetch(path: string, init?: RequestInit): Promise<any> {
  const url = `${RUNTIME_BASE}/skill-api${path}`;
  const res = await fetch(url, {
    ...init,
    headers: { 'Content-Type': 'application/json', ...(init?.headers || {}) },
  });
  const body = await res.json();
  if (body && body.code !== undefined && body.code !== 0 && body.code !== 200) {
    throw new Error(body.msg || `技能服务错误 (${body.code})`);
  }
  let data = body?.data !== undefined ? body.data : body;
  // 服务端可能把 data 再包成 JSON 字符串，最多解三层
  for (let i = 0; i < 3; i++) {
    if (typeof data === 'string') {
      try { data = JSON.parse(data); } catch { break; }
    } else break;
  }
  return data;
}

function buildMeta(s: {
  skillId?: string; scope: 'official' | 'private'; icon: string;
  params: SkillParam[]; trigger: string; tools: string[];
  estCredits: [number, number]; category: string; source: SkillMeta['source'];
}): SkillMeta {
  return {
    skill_id: s.skillId || '',
    scope: s.scope,
    icon: s.icon,
    version: 1,
    status: 'active',
    source: s.source,
    params_schema: s.params,
    trigger: s.trigger,
    tools: s.tools,
    call_count: 0,
    success_count: 0,
    est_credits: s.estCredits,
    category_label: s.category,
  };
}

export const skillApi = {
  /** 列出技能（官方 + 当前用户私有）。category=skill 与普通记忆严格隔离 */
  async list(userId: string): Promise<Skill[]> {
    // 官方技能
    const officialReq = skillFetch('/memory/search', {
      method: 'POST',
      body: JSON.stringify({
        agent_id: 'sylab-ai', category: 'skill',
        tags: ['skill', 'official'], limit: 100,
      }),
    });
    // 私有技能（按 user_id 过滤）
    const privateReq = userId
      ? skillFetch('/memory/search', {
          method: 'POST',
          body: JSON.stringify({
            agent_id: 'sylab-ai', user_id: userId,
            category: 'skill', tags: ['skill', 'private'], limit: 100,
          }),
        })
      : Promise.resolve({ memories: [] });

    const [officialData, privateData] = await Promise.all([officialReq, privateReq]);
    const off = (officialData?.memories || []) as SkillRecord[];
    const pri = (privateData?.memories || []) as SkillRecord[];
    const seen = new Set<number>();
    const out: Skill[] = [];
    [...off, ...pri].forEach((m) => {
      if (seen.has(m.id)) return;
      seen.add(m.id);
      out.push(toSkill(m));
    });
    return out;
  },

  /** 新建用户私有技能。返回新 id */
  async create(input: {
    userId: string; name: string; icon: string; category: string;
    trigger: string; tools: string[]; estCredits: [number, number];
    params: SkillParam[]; content: string;
  }): Promise<number> {
    const skillId = `u-${input.userId}-${Date.now()}`;
    const metadata = buildMeta({
      skillId, scope: 'private', icon: input.icon,
      params: input.params, trigger: input.trigger, tools: input.tools,
      estCredits: input.estCredits, category: input.category, source: 'manual',
    });
    const data = await skillFetch('/memory/save', {
      method: 'POST',
      body: JSON.stringify({
        agent_id: 'sylab-ai', user_id: input.userId,
        layer: 'long_term', category: 'skill',
        tags: ['skill', 'private', input.category],
        title: input.name, content: input.content, importance: 4,
        metadata,
      }),
    });
    return data?.id;
  },

  /** 更新技能内容（保持 skill_id，version+1） */
  async update(recId: number, prev: Skill, patch: Partial<{
    name: string; icon: string; category: string; trigger: string;
    tools: string[]; estCredits: [number, number]; params: SkillParam[]; content: string;
  }>): Promise<void> {
    const metadata: SkillMeta = {
      skill_id: prev.skillId,
      scope: prev.scope,
      icon: patch.icon ?? prev.icon,
      version: prev.version + 1,
      status: 'active',
      source: 'manual',
      params_schema: patch.params ?? prev.params,
      trigger: patch.trigger ?? prev.trigger,
      tools: patch.tools ?? prev.tools,
      call_count: prev.callCount,
      success_count: prev.successCount,
      est_credits: patch.estCredits ?? prev.estCredits,
      category_label: patch.category ?? prev.category,
    };
    await skillFetch('/memory/update', {
      method: 'POST',
      body: JSON.stringify({
        id: recId,
        title: patch.name ?? prev.name,
        content: patch.content ?? prev.content,
        tags: ['skill', prev.scope, patch.category ?? prev.category],
        metadata,
      }),
    });
  },

  /** 删除技能（仅私有；官方不允许前端删） */
  async remove(recId: number): Promise<void> {
    await skillFetch(`/memory/delete?id=${recId}`, { method: 'DELETE' });
  },

  /** 引用一次：调用计数 +1（成功由调用方决定是否再加 success） */
  async incrementCall(recId: number, prev: Skill, success?: boolean): Promise<void> {
    try {
      const metadata: SkillMeta = {
        skill_id: prev.skillId, scope: prev.scope, icon: prev.icon,
        version: prev.version, status: 'active', source: 'manual',
        params_schema: prev.params, trigger: prev.trigger, tools: prev.tools,
        call_count: prev.callCount + 1,
        success_count: prev.successCount + (success ? 1 : 0),
        est_credits: prev.estCredits, category_label: prev.category,
      };
      await skillFetch('/memory/update', {
        method: 'POST',
        body: JSON.stringify({ id: recId, metadata }),
      });
    } catch {
      /* 计数失败不阻塞主流程 */
    }
  },
};
