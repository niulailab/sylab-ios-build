/**
 * 技能库 Tab（全屏）：浏览 / 搜索 / 分类筛选官方与我的技能；
 * 点技能 -> 带技能直接进入与 sylab AI 的对话；支持新建、编辑、删除私有技能。
 * 纯新增页面。
 */
import React, { useCallback, useEffect, useMemo, useState } from 'react';
import {
  ActivityIndicator, Alert, FlatList, Platform, Pressable,
  RefreshControl, StyleSheet, Text, TextInput, View,
} from 'react-native';
import { useRouter } from 'expo-router';
import { skillApi, Skill } from '../../src/api/skill';
import { useAuthStore } from '../../src/store/auth';
import { setPendingSkill } from '../../src/store/pendingSkill';
import { Colors } from '../../src/constants/theme';
import { useTheme } from '../../src/hooks/useTheme';
import SkillEditor from '../../src/components/SkillEditor';

const DEFAULT_BOT_ID = '7669580347859795968';

type Row =
  | { type: 'header'; key: string; title: string }
  | { type: 'item'; key: string; skill: Skill }
  | { type: 'blank'; key: string };

export default function SkillsTab() {
  const router = useRouter();
  const { isDark } = useTheme();
  const user = useAuthStore((s) => s.user);

  const [loading, setLoading] = useState(true);
  const [refreshing, setRefreshing] = useState(false);
  const [skills, setSkills] = useState<Skill[]>([]);
  const [query, setQuery] = useState('');
  const [cat, setCat] = useState('全部');
  const [editorOpen, setEditorOpen] = useState(false);
  const [editing, setEditing] = useState<Skill | null>(null);

  const C = useMemo(() => (isDark ? Dark : Light), [isDark]);

  const load = useCallback(async () => {
    try {
      const list = await skillApi.list(user?.id || '');
      setSkills(list);
    } catch (e: any) {
      Alert.alert('加载失败', e?.message || '请稍后重试');
    } finally {
      setLoading(false);
      setRefreshing(false);
    }
  }, [user?.id]);

  useEffect(() => { load(); }, [load]);

  const onRefresh = () => { setRefreshing(true); load(); };

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

  const mine = filtered.filter((x) => x.scope === 'private');
  const official = filtered.filter((x) => x.scope === 'official');

  const rows = useMemo<Row[]>(() => {
    const r: Row[] = [];
    r.push({ type: 'item', key: 'newbtn', skill: null as unknown as Skill });
    if (mine.length) {
      r.push({ type: 'header', key: 'h-mine', title: `我的技能 · ${mine.length}` });
      mine.forEach((sk) => r.push({ type: 'item', key: `m-${sk.id}`, skill: sk }));
    }
    r.push({ type: 'header', key: 'h-off', title: `官方技能 · ${official.length}` });
    if (official.length) {
      official.forEach((sk) => r.push({ type: 'item', key: `o-${sk.id}`, skill: sk }));
    } else {
      r.push({ type: 'blank', key: 'off-empty' });
    }
    return r;
  }, [mine, official]);

  const openChatWith = async (sk: Skill) => {
    try {
      // 先暂存待引用技能，再确保有一个会话可进
      setPendingSkill(sk);
      const conv = await chatApiCreate();
      if (conv) router.push(`/chat/${conv}`);
      else {
        // 退回对话 Tab，技能仍在暂存里
        router.push('/(tabs)/chat');
      }
    } catch {
      Alert.alert('提示', '打开对话失败，请重试');
      setPendingSkill(null);
    }
  };

  const chatApiCreate = async (): Promise<string> => {
    const conv = await import('../../src/api/chat').then((m) =>
      m.chatApi.createConversation(DEFAULT_BOT_ID, '', user?.id || ''));
    return conv?.id || conv?.conversation_id || '';
  };

  const onDelete = (sk: Skill) => {
    Alert.alert('删除技能', `确定删除「${sk.name}」吗？`, [
      { text: '取消', style: 'cancel' },
      {
        text: '删除', style: 'destructive',
        onPress: async () => {
          try {
            await skillApi.remove(sk.id);
            setSkills((prev) => prev.filter((x) => x.id !== sk.id));
          } catch (e: any) {
            Alert.alert('删除失败', e?.message || '请稍后重试');
          }
        },
      },
    ]);
  };

  const renderItem = ({ item }: { item: Row }) => {
    if (item.type === 'header') {
      return <Text style={[st.sectionTitle, { color: C.textTertiary }]}>{item.title}</Text>;
    }
    if (item.type === 'blank') {
      return <Text style={[st.blank, { color: C.textTertiary }]}>没有匹配的官方技能</Text>;
    }
    if (item.key === 'newbtn') {
      return (
        <Pressable
          onPress={() => { setEditing(null); setEditorOpen(true); }}
          style={[st.createCard, { backgroundColor: C.primarySoft, borderColor: C.primary }]}
        >
          <Text style={[st.createIcon, { color: C.primary }]}>＋</Text>
          <View>
            <Text style={[st.createTitle, { color: C.primary }]}>新建技能</Text>
            <Text style={[st.createSub, { color: C.textSecondary }]}>把常用流程沉淀成可一键引用的 SOP</Text>
          </View>
        </Pressable>
      );
    }
    const sk = item.skill;
    return (
      <Pressable
        onPress={() => openChatWith(sk)}
        style={({ pressed }: { pressed: boolean }) => [
          st.card, { backgroundColor: C.surfaceSecondary, borderColor: C.border }, pressed && st.pressed]}
      >
        <View style={[st.iconBox, { backgroundColor: C.surface }]}>
          <Text style={st.icon}>{sk.icon}</Text>
        </View>
        <View style={st.cardBody}>
          <View style={st.cardTop}>
            <Text style={[st.name, { color: C.text }]} numberOfLines={1}>{sk.name}</Text>
            <Text style={[st.credit, { color: C.textTertiary }]}>约{sk.estCredits[0]}-{sk.estCredits[1]}分</Text>
          </View>
          {!!sk.trigger && (
            <Text style={[st.trigger, { color: C.textSecondary }]} numberOfLines={2}>{sk.trigger}</Text>
          )}
          <View style={st.metaRow}>
            <View style={[st.catTag, { backgroundColor: C.surface }]}>
              <Text style={[st.catTagTxt, { color: C.textSecondary }]}>{sk.category}</Text>
            </View>
            {!!sk.callCount && (
              <Text style={[st.callTxt, { color: C.textTertiary }]}>用过 {sk.callCount} 次</Text>
            )}
            {sk.scope === 'private' && (
              <View style={st.actions}>
                <Pressable hitSlop={8} onPress={() => { setEditing(sk); setEditorOpen(true); }}>
                  <Text style={[st.editTxt, { color: C.primary }]}>编辑</Text>
                </Pressable>
                <Pressable hitSlop={8} onPress={() => onDelete(sk)}>
                  <Text style={[st.delTxt, { color: C.danger }]}>删除</Text>
                </Pressable>
              </View>
            )}
          </View>
        </View>
      </Pressable>
    );
  };

  return (
    <View style={[st.root, { backgroundColor: C.background }]}>
      <View style={[st.searchRow, { backgroundColor: C.surface }]}>
        <TextInput
          style={[st.search, { backgroundColor: C.surfaceSecondary, color: C.text }]}
          placeholder="搜索技能 / 工具 / 场景"
          placeholderTextColor={C.textTertiary}
          value={query}
          onChangeText={setQuery}
          returnKeyType="search"
        />
      </View>

      <View style={st.catRow}>
        <FlatList
          horizontal
          showsHorizontalScrollIndicator={false}
          data={cats}
          keyExtractor={(c: string) => c}
          renderItem={({ item: c }: { item: string }) => (
            <Pressable
              onPress={() => setCat(c)}
              style={[st.catChip, { backgroundColor: cat === c ? C.primary : C.surfaceSecondary }]}
            >
              <Text style={[st.catTxt, { color: cat === c ? '#fff' : C.textSecondary }]}>{c}</Text>
            </Pressable>
          )}
        />
      </View>

      {loading ? (
        <View style={st.center}><ActivityIndicator color={C.primary} /></View>
      ) : (
        <FlatList
          data={rows}
          keyExtractor={(it: Row) => it.key}
          renderItem={renderItem}
          contentContainerStyle={{ paddingHorizontal: 16, paddingBottom: 32, paddingTop: 4 }}
          refreshControl={
            <RefreshControl refreshing={refreshing} onRefresh={onRefresh} tintColor={C.primary} />
          }
        />
      )}

      <SkillEditor
        visible={editorOpen}
        userId={user?.id || ''}
        edit={editing}
        onClose={() => setEditorOpen(false)}
        onSaved={() => { setEditorOpen(false); load(); }}
      />
    </View>
  );
}

const Light = {
  background: Colors.background, surface: Colors.surface, surfaceSecondary: Colors.surfaceSecondary,
  text: Colors.text, textSecondary: Colors.textSecondary, textTertiary: Colors.textTertiary,
  primary: Colors.primary, primarySoft: `rgba(${Colors.primaryRgb},0.08)`,
  danger: Colors.danger, border: 'rgba(15,23,42,0.06)',
};
const Dark = {
  background: '#0f172a', surface: Colors.surfaceDark, surfaceSecondary: Colors.surfaceSecondaryDark,
  text: '#f1f5f9', textSecondary: '#cbd5e1', textTertiary: '#94a3b8',
  primary: Colors.primaryTint, primarySoft: `rgba(${Colors.primaryRgb},0.18)`,
  danger: Colors.danger, border: 'rgba(255,255,255,0.08)',
};

const st = StyleSheet.create({
  root: { flex: 1 },
  center: { flex: 1, alignItems: 'center', justifyContent: 'center' },
  searchRow: { paddingHorizontal: 16, paddingTop: Platform.OS === 'ios' ? 10 : 12, paddingBottom: 8 },
  search: { borderRadius: 12, paddingHorizontal: 14, paddingVertical: 10, fontSize: 15 },
  catRow: { paddingHorizontal: 12, paddingVertical: 6 },
  catChip: { paddingHorizontal: 14, paddingVertical: 7, borderRadius: 18, marginHorizontal: 4 },
  catTxt: { fontSize: 13, fontWeight: '600' },
  sectionTitle: { fontSize: 13, fontWeight: '700', marginTop: 14, marginBottom: 8, marginHorizontal: 4 },
  blank: { fontSize: 13, marginHorizontal: 4, marginBottom: 12 },
  createCard: {
    flexDirection: 'row', alignItems: 'center', gap: 12,
    borderWidth: 1.5, borderStyle: 'dashed', borderRadius: 14,
    padding: 14, marginTop: 6,
  },
  createIcon: { fontSize: 26, fontWeight: '700' },
  createTitle: { fontSize: 15, fontWeight: '700' },
  createSub: { fontSize: 12, marginTop: 2 },
  card: {
    flexDirection: 'row', gap: 12, borderRadius: 14, borderWidth: 1,
    padding: 13, marginBottom: 10,
  },
  pressed: { opacity: 0.7 },
  iconBox: { width: 46, height: 46, borderRadius: 12, alignItems: 'center', justifyContent: 'center' },
  icon: { fontSize: 24 },
  cardBody: { flex: 1, minWidth: 0 },
  cardTop: { flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', gap: 8 },
  name: { fontSize: 15, fontWeight: '700', flexShrink: 1 },
  credit: { fontSize: 12 },
  trigger: { fontSize: 13, marginTop: 3 },
  metaRow: { flexDirection: 'row', alignItems: 'center', flexWrap: 'wrap', gap: 8, marginTop: 8 },
  catTag: { borderRadius: 6, paddingHorizontal: 8, paddingVertical: 3 },
  catTagTxt: { fontSize: 11, fontWeight: '600' },
  callTxt: { fontSize: 11 },
  actions: { flexDirection: 'row', gap: 14, marginLeft: 'auto' },
  editTxt: { fontSize: 12, fontWeight: '700' },
  delTxt: { fontSize: 12, fontWeight: '700' },
});
