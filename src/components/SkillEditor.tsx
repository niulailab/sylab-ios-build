/**
 * 技能创建/编辑器（纯新增）。
 * 支持手填，也支持直接粘贴一段 SOP/markdown；保存为用户私有技能。
 */
import React, { useMemo, useState } from 'react';
import {
  ActivityIndicator, Modal, Pressable, ScrollView, StyleSheet, Text, TextInput, View,
} from 'react-native';
import { skillApi, Skill, SkillParam } from '../api/skill';
import type { SkillDraft } from '../api/skillExtract';
import { Colors } from '../constants';

interface Props {
  visible: boolean;
  userId: string;
  edit?: Skill | null; // 传则编辑
  draft?: SkillDraft | null; // AI 提炼提案，预填表单，用户确认后才入库
  onClose: () => void;
  onSaved: () => void;
}

const ICONS = ['🧩', '✍️', '🖼️', '🎬', '📺', '📊', '📱', '💡', '🔥', '🎨'];

const SkillEditor: React.FC<Props> = ({ visible, userId, edit, draft, onClose, onSaved }) => {
  const [name, setName] = useState(edit?.name || '');
  const [icon, setIcon] = useState(edit?.icon || '🧩');
  const [category, setCategory] = useState(edit?.category || '自定义');
  const [trigger, setTrigger] = useState(edit?.trigger || '');
  const [toolsText, setToolsText] = useState((edit?.tools || []).join(','));
  const [paramsText, setParamsText] = useState(
    (edit?.params || []).map((p) => `${p.name}${p.required ? '*' : ''}`).join(','),
  );
  const [content, setContent] = useState(edit?.content || '');
  const [saving, setSaving] = useState(false);
  const [err, setErr] = useState('');

  const isEdit = !!edit;

  // AI 提案：打开编辑器且带了 draft 时，用提案预填，用户可修改后再保存
  React.useEffect(() => {
    if (visible && draft) {
      setName(draft.name || '');
      setIcon(draft.icon || '🧩');
      setCategory(draft.category || '自定义');
      setTrigger(draft.trigger || '');
      setToolsText((draft.tools || []).join(','));
      setParamsText(
        (draft.params || []).map((p) => `${p.name}${p.required ? '*' : ''}`).join(','),
      );
      setContent(draft.content || '');
      setErr('');
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [visible, draft]);

  const parseParams = (txt: string): SkillParam[] =>
    txt.split(/[,，\n]/).map((x) => x.trim()).filter(Boolean).map((x) => {
      const required = x.endsWith('*');
      return { name: required ? x.slice(0, -1) : x, required, desc: '', example: '' };
    });

  const parseTools = (txt: string): string[] =>
    Array.from(new Set(txt.split(/[,，\n]/).map((x) => x.trim()).filter(Boolean)));

  const canSave = useMemo(() => name.trim() && content.trim(), [name, content]);

  const save = async () => {
    if (!canSave) { setErr('请至少填写技能名称和执行说明'); return; }
    setSaving(true); setErr('');
    try {
      const tools = parseTools(toolsText);
      const params = parseParams(paramsText);
      if (isEdit && edit) {
        await skillApi.update(edit.id, edit, {
          name: name.trim(), icon, category: category.trim() || '自定义',
          trigger: trigger.trim(), tools, estCredits: edit.estCredits, params, content,
        });
      } else {
        await skillApi.create({
          userId, name: name.trim(), icon, category: category.trim() || '自定义',
          trigger: trigger.trim(), tools, estCredits: [0, 0], params, content,
        });
      }
      onSaved();
    } catch (e: any) {
      setErr(e?.message || '保存失败');
    } finally {
      setSaving(false);
    }
  };

  return (
    <Modal visible={visible} animationType="slide" transparent onRequestClose={onClose}>
      <Pressable style={s.backdrop} onPress={onClose}>
        <Pressable style={s.sheet} onPress={(e: any) => e?.stopPropagation?.()}>
          <View style={s.header}>
            <Text style={s.title}>{isEdit ? '编辑技能' : '新建技能'}</Text>
            <Pressable hitSlop={8} onPress={onClose}><Text style={s.close}>✕</Text></Pressable>
          </View>

          <ScrollView keyboardShouldPersistTaps="handled" contentContainerStyle={{ paddingBottom: 30 }}>
            <Text style={s.label}>图标</Text>
            <View style={s.iconRow}>
              {ICONS.map((ic) => (
                <Pressable key={ic} onPress={() => setIcon(ic)} style={[s.iconPick, icon === ic && s.iconPickOn]}>
                  <Text style={{ fontSize: 20 }}>{ic}</Text>
                </Pressable>
              ))}
            </View>

            <Text style={s.label}>技能名称 *</Text>
            <TextInput style={s.input} value={name} onChangeText={setName} placeholder="如：公众号爆款配图包" placeholderTextColor={Colors.textTertiary} />

            <Text style={s.label}>分类</Text>
            <TextInput style={s.input} value={category} onChangeText={setCategory} placeholder="如：生图 / 漫剧 / 文案" placeholderTextColor={Colors.textTertiary} />

            <Text style={s.label}>适用场景</Text>
            <TextInput style={s.input} value={trigger} onChangeText={setTrigger} placeholder="什么情况下用这个技能" placeholderTextColor={Colors.textTertiary} />

            <Text style={s.label}>用到的工具（逗号分隔）</Text>
            <TextInput style={s.input} value={toolsText} onChangeText={setToolsText} placeholder="如：web_search,laneai" placeholderTextColor={Colors.textTertiary} autoCapitalize="none" />

            <Text style={s.label}>输入参数（逗号分隔，带 * 为必填）</Text>
            <TextInput style={s.input} value={paramsText} onChangeText={setParamsText} placeholder="如：主题*,风格,数量" placeholderTextColor={Colors.textTertiary} autoCapitalize="none" />

            <Text style={s.label}>执行说明（SOP）*</Text>
            <TextInput
              style={[s.input, s.area]}
              value={content}
              onChangeText={setContent}
              placeholder={
                '可直接粘贴一段标准操作流程，例如：\n# 目标\n## 输入参数\n- 主题：{主题}\n## 步骤\n1. ...\n2. ...\n## 输出\n## 约束'
              }
              placeholderTextColor={Colors.textTertiary}
              multiline
              textAlignVertical="top"
            />

            {!!err && <Text style={s.err}>{err}</Text>}

            <Pressable style={[s.saveBtn, !canSave && s.saveBtnDisabled]} onPress={save} disabled={saving || !canSave}>
              {saving ? <ActivityIndicator color="#fff" /> : <Text style={s.saveTxt}>{isEdit ? '保存修改' : '保存技能'}</Text>}
            </Pressable>
          </ScrollView>
        </Pressable>
      </Pressable>
    </Modal>
  );
};

const s = StyleSheet.create({
  backdrop: { flex: 1, backgroundColor: 'rgba(0,0,0,0.45)', justifyContent: 'flex-end' },
  sheet: { backgroundColor: Colors.surface, borderTopLeftRadius: 20, borderTopRightRadius: 20, maxHeight: '92%', paddingHorizontal: 16, paddingTop: 14 },
  header: { flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', marginBottom: 8 },
  title: { fontSize: 18, fontWeight: '700', color: Colors.text },
  close: { fontSize: 18, color: Colors.textTertiary, paddingHorizontal: 6 },
  label: { fontSize: 13, fontWeight: '600', color: Colors.textSecondary, marginTop: 14, marginBottom: 6 },
  input: { backgroundColor: Colors.surfaceSecondary, borderRadius: 10, paddingHorizontal: 12, paddingVertical: 9, fontSize: 15, color: Colors.text },
  area: { minHeight: 180 },
  iconRow: { flexDirection: 'row', flexWrap: 'wrap', gap: 8 },
  iconPick: { width: 42, height: 42, borderRadius: 10, backgroundColor: Colors.surfaceSecondary, alignItems: 'center', justifyContent: 'center' },
  iconPickOn: { borderWidth: 2, borderColor: Colors.primary },
  err: { color: Colors.danger, fontSize: 13, marginTop: 12 },
  saveBtn: { backgroundColor: Colors.primary, borderRadius: 12, paddingVertical: 13, alignItems: 'center', marginTop: 18 },
  saveBtnDisabled: { opacity: 0.5 },
  saveTxt: { color: '#fff', fontWeight: '700', fontSize: 16 },
});

export default SkillEditor;
