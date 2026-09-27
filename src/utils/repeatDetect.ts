/**
 * 轻量「重复流程」检测：纯本地规则，不调用 LLM、不增加后端成本。
 *
 * 思路：把用户消息切成 token（中文按单字、英文/数字按词），用
 * “包含系数”(overlap = 交集 token 数 / 较短句 token 数) 判断两条
 * 请求是否属于同一类固定流程——即便具体对象不同，例如
 * “给乳胶枕写详情页” vs “给保温杯写详情页”。
 *
 * 相比 Jaccard，包含系数对“长短不一但动作相同”的中文请求更稳。
 * 仅在同一会话检测到第 2 条及以上相似任务时提示一次，避免打扰。
 * 纯新增，不影响任何历史逻辑。
 */

/** 明显不是“任务型流程”的消息：寒暄、短确认等 */
const NON_TASK_PATTERN =
  /^(你好|您好|hi|hello|hey|在吗|在不在|谢谢|感谢|多谢|好的|好吧|行|嗯|嗯嗯|哦|噢|ok|okay|yes|no|对|不对|是|不是|收到|哈哈哈+|哈+|早安|晚安|早上好|晚上好)[\s!！。.~～]*$/i;

/** 切成 token：连续英文/数字作为一个词，每个汉字单独作为 token */
export function tokenize(text: string): string[] {
  const t = String(text || '').toLowerCase();
  const m = t.match(/[a-z0-9]+|[\u4e00-\u9fff]/g);
  return m || [];
}

/** 包含系数 0~1：较短请求中有多少 token 出现在较长请求里 */
export function overlapScore(a: string, b: string): number {
  const A = new Set(tokenize(a));
  const B = new Set(tokenize(b));
  if (A.size === 0 || B.size === 0) return 0;
  let inter = 0;
  for (const x of A) if (B.has(x)) inter++;
  return inter / Math.min(A.size, B.size);
}

/** 是否像一条“可执行任务”（而非寒暄/纯占位） */
export function isTaskMessage(text: string): boolean {
  const raw = String(text || '').trim();
  if (raw.length < 6) return false;
  if (/^\[(图片|照片|image|文件|file|语音|音频|video|视频)\].*$/i.test(raw)) return false;
  if (NON_TASK_PATTERN.test(raw)) return false;
  return tokenize(raw).length >= 4;
}

export interface RepeatHit {
  matched: boolean;
  /** 与当前请求相似的历史任务条数（不含当前） */
  count: number;
  /** 最高相似度，便于调试 */
  score: number;
}

/**
 * 判断 latestUserText 是否与 priorUserTexts 中已有任务构成“重复流程”。
 * 至少 1 条历史任务包含系数 >= threshold（即同类流程出现第 2 次）。
 */
export function detectRepeat(
  priorUserTexts: Array<string | null | undefined>,
  latestUserText: string,
  threshold = 0.4,
): RepeatHit {
  if (!isTaskMessage(latestUserText)) return { matched: false, count: 0, score: 0 };
  let count = 0;
  let score = 0;
  for (const p0 of priorUserTexts) {
    if (p0 == null) continue;
    const p = String(p0);
    if (!isTaskMessage(p)) continue;
    const s = overlapScore(latestUserText, p);
    if (s >= threshold) {
      count += 1;
      if (s > score) score = s;
    }
  }
  return { matched: count >= 1, count, score };
}

/**
 * 口头指令识别：用户直接用自然语言要求“现场制作并保存技能”。
 * 命中关键词且包含“技能/skill”，并带有“创建/做/生成/存/保存/沉淀/提炼”等动作。
 */
const SKILL_NOUN = /(技能|skill|sop|模板)/i;
const SKILL_MAKE_VERB =
  /(创建|新建|创造|制作|生成|做(?:一?个|成)?|写(?:一?个)?|沉淀|提炼|总结成|整理成|保存|存(?:到|进|入|一?个)?|搞(?:一?个)?)/;

export interface VoiceSkillIntent {
  hit: boolean;
  /** 可能附带的技能名称，如“做一个叫xx的技能” */
  name: string;
}

export function parseVoiceSkillIntent(text: string): VoiceSkillIntent {
  const t = String(text || '').trim();
  if (!t) return { hit: false, name: '' };
  if (!SKILL_NOUN.test(t)) return { hit: false, name: '' };
  if (!SKILL_MAKE_VERB.test(t)) return { hit: false, name: '' };
  // 尝试抽取 “叫/命名为/名为 XX” 的名称
  let name = '';
  const m =
    t.match(/(?:命名为|取名为|名字叫|叫(?:做)?|名称为|名为)\s*[「“『"]?([\u4e00-\u9fffA-Za-z0-9·]{2,20})[」”’"]?/);
  if (m) name = m[1];
  return { hit: true, name };
}
