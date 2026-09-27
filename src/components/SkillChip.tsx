/**
 * 已引用技能的输入框 chip（纯新增）。展示图标+名称+预估积分，可移除。
 */
import React from 'react';
import { Pressable, StyleSheet, Text, View } from 'react-native';
import { Skill } from '../../api/skill';
import { Colors } from '../../constants';

interface Props {
  skill: Skill;
  onRemove: () => void;
}

const SkillChip: React.FC<Props> = ({ skill, onRemove }) => (
  <View style={s.chip}>
    <Text style={s.icon}>{skill.icon}</Text>
    <View style={s.body}>
      <Text style={s.name} numberOfLines={1}>{skill.name}</Text>
      <Text style={s.meta}>
        {skill.params.filter((p) => p.required).map((p) => `{${p.name}}`).join(' ') || '技能'}
        {skill.estCredits[1] > 0 ? ` · 约${skill.estCredits[0]}-${skill.estCredits[1]}分` : ''}
      </Text>
    </View>
    <Pressable hitSlop={8} onPress={onRemove} style={s.x}>
      <Text style={s.xTxt}>✕</Text>
    </Pressable>
  </View>
);

const s = StyleSheet.create({
  chip: {
    flexDirection: 'row', alignItems: 'center', gap: 8,
    backgroundColor: '#eef2ff',
    borderRadius: 10, paddingHorizontal: 10, paddingVertical: 7,
  },
  icon: { fontSize: 18 },
  body: { flex: 1, minWidth: 0 },
  name: { fontSize: 13, fontWeight: '700', color: Colors.text },
  meta: { fontSize: 11, color: Colors.textSecondary, marginTop: 1 },
  x: { paddingHorizontal: 2 },
  xTxt: { fontSize: 13, color: Colors.textTertiary },
});

export default SkillChip;
