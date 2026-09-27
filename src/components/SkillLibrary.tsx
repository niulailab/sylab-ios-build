/**
 * 技能库选择面板（纯新增组件，不修改 MarkdownRenderer 等既有文件）。
 * 打开后：搜索 + 分类筛选 + 官方/我的分区，选中即回调引用。
 */
import React, { useCallback, useEffect, useMemo, useState } from 'react';
import {
  ActivityIndicator, FlatList, Modal, Pressable, StyleSheet, Text, TextInput, View,
} from 'react-native';
import { skillApi, Skill } from '../api/skill';
import { Colors } from '../constants';

interface Props {
  visible: boolean;
  userId: string;
  onClose: () => void;
  onPick: (skill: Skill) => void;
  onCreate: () => void;
}

const SectionHeader: React.FC<{ title: string }> = ({ title }) => (
  <View style={s.sectionHeader}>
    <Text style={s.sectionTitle}>{title}</Text>
  </View>
);

const SkillLibrary: React.FC<Props> = ({ visible, userId, onClose, onPick, onCreate }) => {
  const [loading, setLoading] = useState(false);
  const [skills, setSkills] = useState<Skill[]>([]);
  const [query, setQuery] = useState('');
  const [cat, setCat] = useState<string>('全部');
  const [err, setErr] = useState('');

  const load = useCallback(async () => {
    setLoading(true); setErr('');
    try {
      const list = await skillApi.list(userId);
      setSkills(list);
    } catch (e: any) {
      setErr(e?.message || '加载失败');
    } finally {
      setLoading(false);
    }
  }, [userId]);

  useEffect(() => {
    if (visible) load();
  }, [visible, load]);

  const cats = useMemo(() => {
    const set = new Set<string>();
    skills.forEach((x) => set.add(x.category));
    return ['全部', ...Array.from(set)];
  }, [skills]);

  const filtered = useMemo(() => {
    const q = query.trim().toLowerCase();
    return skills.filter((x) => {
      if (cat !== '全部' && x.category !== cat) return false;
      if (!q) return true;
      return (
        x.name.toLowerCase().includes(q) ||
        x.trigger.toLowerCase().includes(q) ||
        x.tools.join(',').toLowerCase().includes(q)
      );
    });
  }, [skills, query, cat]);

  const official = filtered.filter((x) => x.scope === 'official');
  const mine = filtered.filter((x) => x.scope === 'private');

  // 用分组数据：先我的后官方
  const data = useMemo(() => {
    const rows: Array<{ type: 'header'; key: string; title: string } | { type: 'item'; key: string; skill: Skill }> = [];
    if (mine.length) {
      rows.push({ type: 'header', key: 'h-mine', title: `我的技能 (${mine.length})` });
      mine.forEach((sk) => rows.push({ type: 'item', key: `m-${sk.id}`, skill: sk }));
    }
    if (official.length) {
      rows.push({ type: 'header', key: 'h-off', title: `官方技能 (${official.length})` });
      official.forEach((sk) => rows.push({ type: 'item', key: `o-${sk.id}`, skill: sk }));
    }
    return rows;
  }, [mine, official]);

  const renderRow = ({ item }: { item: (typeof data)[number] }) => {
    if (item.type === 'header') return <SectionHeader title={item.title} />;
    const sk = item.skill;
    return (
      <Pressable
        style={({ pressed }: { pressed: boolean }) => [s.card, pressed && s.cardPressed]}
        onPress={() => onPick(sk)}
      >
        <View style={s.iconBox}><Text style={s.icon}>{sk.icon}</Text></View>
        <View style={s.cardBody}>
          <View style={s.cardTop}>
            <Text style={s.name} numberOfLines={1}>{sk.name}</Text>
            <Text style={s.credit}>约{sk.estCredits[0]}-{sk.estCredits[1]}分</Text>
          </View>
          {!!sk.trigger && <Text style={s.trigger} numberOfLines={2}>{sk.trigger}</Text>}
          {!!sk.tools.length && (
            <View style={s.toolRow}>
              {sk.tools.slice(0, 4).map((t) => (
                <View key={t} style={s.toolChip}><Text style={s.toolText}>{t}</Text></View>
              ))}
              {!!sk.callCount && <Text style={s.callTxt}>用过{sk.callCount}次</Text>}
            </View>
          )}
        </View>
      </Pressable>
    );
  };

  return (
    <Modal visible={visible} animationType="slide" transparent onRequestClose={onClose}>
      <View style={s.backdrop}>
        <View style={s.sheet}>
          <View style={s.header}>
            <Text style={s.title}>技能库</Text>
            <Pressable hitSlop={8} onPress={onClose}><Text style={s.close}>✕</Text></Pressable>
          </View>

          <View style={s.searchRow}>
            <TextInput
              style={s.search}
              placeholder="搜索技能 / 工具 / 场景"
              placeholderTextColor={Colors.textTertiary}
              value={query}
              onChangeText={setQuery}
              returnKeyType="search"
            />
            <Pressable style={s.createBtn} onPress={onCreate}>
              <Text style={s.createTxt}>＋ 新建</Text>
            </Pressable>
          </View>

          <View style={s.catRow}>
            <FlatList
              horizontal
              showsHorizontalScrollIndicator={false}
              data={cats}
              keyExtractor={(c: string) => c}
              renderItem={({ item: c }: { item: string }) => (
                <Pressable onPress={() => setCat(c)} style={[s.catChip, cat === c && s.catChipOn]}>
                  <Text style={[s.catTxt, cat === c && s.catTxtOn]}>{c}</Text>
                </Pressable>
              )}
            />
          </View>

          {loading ? (
            <View style={s.center}><ActivityIndicator color={Colors.primary} /></View>
          ) : err ? (
            <View style={s.center}>
              <Text style={s.errTxt}>{err}</Text>
              <Pressable onPress={load} style={s.retry}><Text style={s.retryTxt}>重试</Text></Pressable>
            </View>
          ) : data.length === 0 ? (
            <View style={s.center}>
              <Text style={s.emptyTxt}>没有匹配的技能</Text>
              <Pressable onPress={onCreate} style={s.retry}><Text style={s.retryTxt}>自己建一个</Text></Pressable>
            </View>
          ) : (
            <FlatList
              data={data}
              keyExtractor={(it: { key: string }) => it.key}
              renderItem={renderRow}
              contentContainerStyle={{ paddingBottom: 24 }}
              keyboardShouldPersistTaps="handled"
            />
          )}
        </View>
      </View>
    </Modal>
  );
};

const s = StyleSheet.create({
  backdrop: { flex: 1, backgroundColor: 'rgba(0,0,0,0.45)', justifyContent: 'flex-end' },
  sheet: {
    backgroundColor: Colors.surface, borderTopLeftRadius: 20, borderTopRightRadius: 20,
    maxHeight: '88%', paddingHorizontal: 16, paddingTop: 14,
  },
  header: { flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', marginBottom: 10 },
  title: { fontSize: 18, fontWeight: '700', color: Colors.text },
  close: { fontSize: 18, color: Colors.textTertiary, paddingHorizontal: 6 },
  searchRow: { flexDirection: 'row', alignItems: 'center', gap: 8 },
  search: {
    flex: 1, backgroundColor: Colors.surfaceSecondary, borderRadius: 10, paddingHorizontal: 12,
    paddingVertical: 9, fontSize: 15, color: Colors.text,
  },
  createBtn: { backgroundColor: Colors.primary, borderRadius: 10, paddingHorizontal: 12, paddingVertical: 9 },
  createTxt: { color: '#fff', fontWeight: '600', fontSize: 14 },
  catRow: { marginVertical: 10 },
  catChip: { paddingHorizontal: 13, paddingVertical: 6, borderRadius: 16, backgroundColor: Colors.surfaceSecondary, marginRight: 8 },
  catChipOn: { backgroundColor: Colors.primary },
  catTxt: { fontSize: 13, color: Colors.textTertiary },
  catTxtOn: { color: '#fff', fontWeight: '600' },
  sectionHeader: { paddingVertical: 8, marginTop: 4 },
  sectionTitle: { fontSize: 13, fontWeight: '700', color: Colors.textTertiary },
  card: {
    flexDirection: 'row', backgroundColor: Colors.surfaceSecondary, borderRadius: 12,
    padding: 12, marginBottom: 8, gap: 10,
  },
  cardPressed: { opacity: 0.7 },
  iconBox: { width: 42, height: 42, borderRadius: 10, backgroundColor: Colors.surface, alignItems: 'center', justifyContent: 'center' },
  icon: { fontSize: 22 },
  cardBody: { flex: 1, minWidth: 0 },
  cardTop: { flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', gap: 8 },
  name: { fontSize: 15, fontWeight: '700', color: Colors.text, flexShrink: 1 },
  credit: { fontSize: 12, color: Colors.textTertiary },
  trigger: { fontSize: 13, color: Colors.textSecondary, marginTop: 3 },
  toolRow: { flexDirection: 'row', alignItems: 'center', flexWrap: 'wrap', marginTop: 7, gap: 5 },
  toolChip: { backgroundColor: Colors.surface, borderRadius: 6, paddingHorizontal: 7, paddingVertical: 3 },
  toolText: { fontSize: 11, color: Colors.textSecondary },
  callTxt: { fontSize: 11, color: Colors.textTertiary, marginLeft: 4 },
  center: { paddingVertical: 50, alignItems: 'center' },
  errTxt: { color: Colors.danger, fontSize: 14 },
  emptyTxt: { color: Colors.textTertiary, fontSize: 14, marginBottom: 10 },
  retry: { marginTop: 10, backgroundColor: Colors.primary, borderRadius: 8, paddingHorizontal: 18, paddingVertical: 8 },
  retryTxt: { color: '#fff', fontWeight: '600' },
});

export default SkillLibrary;
