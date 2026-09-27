/**
 * AI 技能提炼：把一段会话历史交给 sylab AI（复用 /v3/chat SSE），
 * 让其产出结构化技能提案 JSON。提案只返回给前端，必须由用户在
 * SkillEditor 中确认/修改后才入库——AI 不会私自写技能库。
 * 纯新增模块。
 */
import { sendMessageStream } from './sse';
import { getBearerToken } from './client';
import type { SkillParam } from './skill';

export interface SkillDraft {
  name: string;
  icon: string;
  category: string;
  trigger: string;
  tools: string[];
  params: SkillParam[];
  content: string;
}

export interface ExtractableMessage {
  role: 'user' | 'assistant';
  content: string;
}

export const SKILL_EXTRACT_BOT_ID = '7669580347859795968';

function buildPrompt(messages: ExtractableMessage[]): string {
  const transcript = messages
    .map((m) => `${m.role === 'user' ? '用户' : 'AI'}：${String(m.content || '').slice(0, 4000)}`)
    .join('\n')
    .slice(0, 24000);

  return `你是“技能提炼器”。下面给你一段用户与 AI 的真实对话，请判断其中是否存在可复用的固定流程；若有，提炼成一个结构化技能。

【硬性要求】
- 只输出一个 JSON 对象，不要输出任何解释，不要使用 markdown 代码块。
- JSON 字段：
{"name":"技能名","icon":"一个emoji","category":"分类","trigger":"什么场景下用","tools":["可能用到的工具"],"params":[{"name":"参数名","required":true,"desc":"说明","example":""}],"content":"标准操作流程Markdown，需含 # 标题、## 目标、## 输入参数、## 步骤、## 输出、## 约束"}
- content 的步骤要编号、可执行；对话中没有明确参数时 params 给空数组 []。
- 技能要能脱离本次具体内容复用（把具体商品名/主题抽象成参数）。
- 若对话没有可复用流程，返回 {"empty":true,"reason":"原因"}。

【待提炼对话】
${transcript}`;
}

/** 从可能夹带解释/代码块的文本中稳健提取 JSON 对象 */
function extractJson(text: string): any {
  let t = text.trim();
  const fence = t.match(/```(?:json)?\s*([\s\S]*?)```/i);
  if (fence) t = fence[1].trim();
  const start = t.indexOf('{');
  const end = t.lastIndexOf('}');
  if (start >= 0 && end > start) t = t.slice(start, end + 1);
  return JSON.parse(t);
}

function normalizeDraft(obj: any): SkillDraft | null {
  if (!obj || obj.empty) return null;
  const params: SkillParam[] = Array.isArray(obj.params)
    ? obj.params
        .map((p: any) => ({
          name: String(p?.name || '').trim(),
          required: !!p?.required,
          desc: String(p?.desc || ''),
          example: String(p?.example || ''),
        }))
        .filter((p: SkillParam) => p.name)
    : [];
  const tools = Array.isArray(obj.tools)
    ? obj.tools.map((t: any) => String(t).trim()).filter(Boolean)
    : [];
  const name = String(obj.name || '').trim();
  const content = String(obj.content || '').trim();
  if (!name || !content) return null;
  return {
    name,
    icon: String(obj.icon || '🧩').slice(0, 4) || '🧩',
    category: String(obj.category || '自定义').trim() || '自定义',
    trigger: String(obj.trigger || ''),
    tools,
    params,
    content,
  };
}

export function extractSkillFromMessages(
  messages: ExtractableMessage[],
  userId: string,
  callbacks: {
    onProgress?: (delta: string) => void;
    onDone: (draft: SkillDraft | null, emptyReason?: string) => void;
    onError: (e: Error) => void;
  },
): { abort: () => void } {
  let acc = '';
  let finished = false;
  const bearer = getBearerToken() || '';

  const stream = sendMessageStream(
    {
      bot_id: SKILL_EXTRACT_BOT_ID,
      user_id: userId || 'extract',
      stream: true,
      auto_save_history: false,
      additional_messages: [
        { role: 'user', content: buildPrompt(messages), content_type: 'text' },
      ],
    },
    bearer,
    {
      onDelta: (d) => {
        acc += d;
        callbacks.onProgress?.(d);
      },
      onComplete: () => {
        if (finished) return;
        finished = true;
        try {
          const obj = extractJson(acc);
          if (obj?.empty) {
            callbacks.onDone(null, String(obj.reason || '这段对话没有可复用流程'));
            return;
          }
          const draft = normalizeDraft(obj);
          callbacks.onDone(draft);
        } catch (e: any) {
          callbacks.onError(new Error('技能提案解析失败，请重试'));
        }
      },
      onError: (e) => {
        if (finished) return;
        finished = true;
        callbacks.onError(e);
      },
    },
  );

  return { abort: stream.abort };
}
