import React, { useState, useEffect, useCallback } from 'react';
import {
  View, Text, FlatList, TouchableOpacity, StyleSheet,
  ActivityIndicator, RefreshControl, Switch,
} from 'react-native';
import { useRouter } from 'expo-router';
import { Ionicons } from '@expo/vector-icons';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { scheduledTasksApi, ScheduledTask } from '../src/api/scheduledTasks';
import { SafeAlert } from '../src/utils/safeAlert';
import { Colors, Spacing, BorderRadius, FontSize, Shadows } from '../src/constants/theme';

const STATUS_COLOR: Record<string, string> = {
  success: '#22c55e',
  failed: '#ef4444',
  running: '#3b82f6',
  '未执行': Colors.textTertiary,
};

export default function ScheduledTasksScreen() {
  const router = useRouter();
  const insets = useSafeAreaInsets();
  const [tasks, setTasks] = useState<ScheduledTask[]>([]);
  const [loading, setLoading] = useState(true);
  const [refreshing, setRefreshing] = useState(false);
  const [busyUuid, setBusyUuid] = useState<string | null>(null);

  const fetchTasks = useCallback(async () => {
    try {
      const d = await scheduledTasksApi.list();
      setTasks(d.tasks);
    } catch (e: any) {
      SafeAlert.alert('加载失败', e?.message || '请稍后再试');
    } finally {
      setLoading(false);
      setRefreshing(false);
    }
  }, []);

  useEffect(() => { fetchTasks(); }, [fetchTasks]);

  // 开关
  const onToggle = useCallback(async (t: ScheduledTask) => {
    if (busyUuid) return;
    const wantPause = t.status === 'active';
    setBusyUuid(t.task_uuid);
    // 乐观更新
    setTasks(prev => prev.map(x =>
      x.task_uuid === t.task_uuid
        ? { ...x, status: wantPause ? 'paused' : 'active' }
        : x));
    try {
      await scheduledTasksApi.toggle(t.task_uuid, wantPause ? 'pause' : 'resume');
    } catch (e: any) {
      // 回滚
      setTasks(prev => prev.map(x =>
        x.task_uuid === t.task_uuid
          ? { ...x, status: wantPause ? 'active' : 'paused' }
          : x));
      SafeAlert.alert('操作失败', e?.message || '请稍后再试');
    } finally {
      setBusyUuid(null);
    }
  }, [busyUuid]);

  // 删除（二次确认）
  const onDelete = useCallback((t: ScheduledTask) => {
    if (busyUuid) return;
    SafeAlert.alert(
      '删除定时任务',
      `确定删除「${t.title}」吗？删除后将不再自动执行。`,
      [
        { text: '取消', style: 'cancel' },
        {
          text: '删除',
          style: 'destructive',
          onPress: async () => {
            setBusyUuid(t.task_uuid);
            try {
              await scheduledTasksApi.remove(t.task_uuid);
              setTasks(prev => prev.filter(x => x.task_uuid !== t.task_uuid));
            } catch (e: any) {
              SafeAlert.alert('删除失败', e?.message || '请稍后再试');
            } finally {
              setBusyUuid(null);
            }
          },
        },
      ],
    );
  }, [busyUuid]);

  const renderItem = ({ item }: { item: ScheduledTask }) => {
    const enabled = item.status === 'active';
    const stColor = STATUS_COLOR[item.last_status] || Colors.textTertiary;
    return (
      <View style={styles.card}>
        <View style={styles.cardTop}>
          <Text style={styles.title} numberOfLines={1}>{item.title || '定时任务'}</Text>
          <Switch
            value={enabled}
            onValueChange={() => onToggle(item)}
            disabled={busyUuid === item.task_uuid}
            trackColor={{ false: '#d1d5db', true: '#8b7cf6' }}
            thumbColor="#fff"
          />
        </View>
        <View style={styles.freqRow}>
          <Ionicons name="time-outline" size={14} color={Colors.textSecondary} />
          <Text style={styles.freqText}>{item.freq_text}</Text>
        </View>
        {item.next_run_at ? (
          <Text style={styles.nextText}>下次执行：{item.next_run_at}</Text>
        ) : null}
        <View style={styles.cardBottom}>
          <View style={styles.statusPill}>
            <View style={[styles.statusDot, { backgroundColor: stColor }]} />
            <Text style={styles.statusText}>
              {item.last_status}
              {item.run_count > 0 ? ` · 已执行${item.run_count}次` : ''}
            </Text>
          </View>
          <TouchableOpacity
            style={styles.delBtn}
            onPress={() => onDelete(item)}
            disabled={busyUuid === item.task_uuid}
            hitSlop={{ top: 8, bottom: 8, left: 8, right: 8 }}
          >
            <Ionicons name="trash-outline" size={18} color="#ef4444" />
          </TouchableOpacity>
        </View>
      </View>
    );
  };

  if (loading) {
    return (
      <View style={[styles.center, { paddingTop: insets.top + 80 }]}>
        <ActivityIndicator size="large" color="#8b7cf6" />
      </View>
    );
  }

  return (
    <View style={styles.container}>
      <View style={[styles.header, { paddingTop: insets.top + Spacing.sm }]}>
        <TouchableOpacity onPress={() => router.back()} hitSlop={{ top: 10, bottom: 10, left: 10, right: 10 }}>
          <Ionicons name="chevron-back" size={26} color={Colors.text} />
        </TouchableOpacity>
        <Text style={styles.headerTitle}>定时任务</Text>
        <View style={{ width: 26 }} />
      </View>

      <FlatList
        contentContainerStyle={styles.listContent}
        data={tasks}
        keyExtractor={t => t.task_uuid}
        renderItem={renderItem}
        refreshControl={
          <RefreshControl refreshing={refreshing} onRefresh={() => { setRefreshing(true); fetchTasks(); }} />
        }
        ListEmptyComponent={
          <View style={styles.empty}>
            <Ionicons name="alarm-outline" size={56} color="#d1d5db" />
            <Text style={styles.emptyTitle}>还没有定时任务</Text>
            <Text style={styles.emptyDesc}>在聊天里告诉 AI「每天/每周几点做什么」即可创建</Text>
          </View>
        }
      />
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: Colors.background },
  center: { flex: 1, backgroundColor: Colors.background, alignItems: 'center' },
  header: {
    flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between',
    paddingHorizontal: Spacing.md, paddingBottom: Spacing.sm,
  },
  headerTitle: { fontSize: FontSize.lg, fontWeight: '700', color: Colors.text },
  listContent: { padding: Spacing.md, paddingBottom: 40, flexGrow: 1 },
  card: {
    backgroundColor: Colors.surface, borderRadius: BorderRadius.lg,
    padding: Spacing.md, marginBottom: Spacing.md, ...Shadows.sm,
  },
  cardTop: { flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between' },
  title: { flex: 1, fontSize: FontSize.md, fontWeight: '600', color: Colors.text, marginRight: Spacing.sm },
  freqRow: { flexDirection: 'row', alignItems: 'center', marginTop: Spacing.xs, gap: 4 },
  freqText: { fontSize: FontSize.sm, color: Colors.textSecondary },
  nextText: { fontSize: FontSize.xs, color: Colors.textTertiary, marginTop: 4 },
  cardBottom: {
    flexDirection: 'row', alignItems: 'center',
    justifyContent: 'space-between', marginTop: Spacing.sm,
  },
  statusPill: { flexDirection: 'row', alignItems: 'center' },
  statusDot: { width: 7, height: 7, borderRadius: 4, marginRight: 6 },
  statusText: { fontSize: FontSize.xs, color: Colors.textSecondary },
  delBtn: { padding: 2 },
  empty: { flex: 1, alignItems: 'center', justifyContent: 'center', paddingTop: 120 },
  emptyTitle: { fontSize: FontSize.lg, fontWeight: '600', color: Colors.text, marginTop: Spacing.md },
  emptyDesc: { fontSize: FontSize.sm, color: Colors.textTertiary, marginTop: 6, textAlign: 'center' },
});
