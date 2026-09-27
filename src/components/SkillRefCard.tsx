/**
 * 用户引用技能时，气泡里展示的紧凑技能卡（纯新增）。
 * 消息原文仍是完整技能指令（AI 照常收到 SOP），这里只负责把它渲染成：
 *   图标 + 技能名 + 本次要求；点“查看 SOP”可展开全文。
 */
import React, { useState } from 'react';
import { Pressable, StyleSheet, Text, View } from 'react-native';
import { Colors } from '../constants';
import { MarkdownRenderer } from './MarkdownRenderer';

export const SKILL_DIRECTIVE_PREFIX = '【技能引用】';

export interface ParsedSkillRef {
  icon: string;
  name: string;
  request: string;
  sop: string;
  raw: string;
}

export function parseSkillDirective(text: string): ParsedSkillRef | null {
  const t = String(text || '');
  if (!t.startsWith(SKILL_DIRECTIVE_PREFIX)) return null;
  const rest = t.slice(SKILL_DIRECTIVE_PREFIX.length);
  const firstNL = rest.indexOf('\n');
  const firstLine = (firstNL >= 0 ? rest.slice(0, firstNL) : rest).trim();

  let icon = '';
  let name = firstLine;
  const m = firstLine.match(/^([^\u4e00-\u9fffA-Za-z0-9]+)\s+(.+)$/);
  if (m) { icon = m[1].trim(); name = m[2].trim(); }
  if (!name) name = firstLine || '技能';

  let sop = '';
  const sM = rest.match(/——技能 SOP 开始——([\s\S]*?)——技能 SOP 结束——/);
  if (sM) sop = sM[1].trim();

  let request = '';
  const rM = rest.match(/用户本次要求：([\s\S]*?)$/);
  if (rM) request = rM[1].trim();
  if (request === '请按技能默认目标执行') request = '';

  return { icon, name, request, sop, raw: t };
}

interface Props {
  content: string;
  textColor: string;
  isDark?: boolean;
}

const SkillRefCard: React.FC<Props> = ({ content, textColor, isDark }) => {
  const parsed = parseSkillDirective(content);
  const [open, setOpen] = useState(false);
  if (!parsed) return <Text selectable>{content}</Text>;

  return (
    <View style={s.card}>
      <View style={s.head}>
        {!!parsed.icon && <Text style={s.icon}>{parsed.icon}</Text>}
        <View style={s.titleWrap}>
          <Text style={[s.name, { color: textColor }]} numberOfLines={1}>{parsed.name}</Text>
          <Text style={s.tag}>技能</Text>
        </View>
      </View>

      {!!parsed.request && (
        <Text style={[s.req, { color: textColor }]} numberOfLines={3}>
          本次要求：{parsed.request}
        </Text>
      )}

      {!!parsed.sop && (
        <Pressable hitSlop={6} onPress={() => setOpen((v) => !v)} style={s.toggle}>
          <Text style={s.toggleTxt}>{open ? '收起 SOP' : '查看 SOP'}</Text>
        </Pressable>
      )}
      {open && !!parsed.sop && (
        <View style={s.sopBox}>
          <MarkdownRenderer content={parsed.sop} isDark={isDark} />
        </View>
      )}
    </View>
  );
};

const s = StyleSheet.create({
  card: { minWidth: 180 },
  head: { flexDirection: 'row', alignItems: 'center', gap: 8 },
  icon: { fontSize: 20 },
  titleWrap: { flexDirection: 'row', alignItems: 'center', gap: 6, flexShrink: 1 },
  name: { fontSize: 15, fontWeight: '700', flexShrink: 1 },
  tag: {
    fontSize: 10, color: Colors.primary, fontWeight: '600',
    overflow: 'hidden', paddingHorizontal: 6, paddingVertical: 1, borderRadius: 6,
    backgroundColor: 'rgba(99,102,241,0.14)',
  },
  req: { fontSize: 13, marginTop: 6, lineHeight: 18 },
  toggle: { marginTop: 6, alignSelf: 'flex-start' },
  toggleTxt: { fontSize: 12, color: Colors.primary, fontWeight: '600' },
  sopBox: {
    marginTop: 6, paddingTop: 6, borderTopWidth: StyleSheet.hairlineWidth,
    borderTopColor: 'rgba(148,163,184,0.4)',
  },
});

export default SkillRefCard;
