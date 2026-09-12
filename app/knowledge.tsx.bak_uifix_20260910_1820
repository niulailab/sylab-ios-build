import React, { useState, useEffect, useCallback } from 'react';
import { View, Text, FlatList, TouchableOpacity, StyleSheet, ActivityIndicator, RefreshControl } from 'react-native';
import { useRouter } from 'expo-router';
import { Ionicons } from '@expo/vector-icons';
import { knowledgeApi } from '../src/api/knowledge';
import { SkeletonLoader } from '../src/components/SkeletonLoader';
import { Colors, Spacing, BorderRadius, FontSize, Shadows } from '../src/constants/theme';
import { useTheme } from '../src/hooks/useTheme';

interface KnowledgeItem {
  id: string;
  name: string;
  description?: string;
  document_count?: number;
  dataset_id?: string;
}

export default function KnowledgeScreen() {
  const router = useRouter();
  const [items, setItems] = useState<KnowledgeItem[]>([]);
  const [loading, setLoading] = useState(true);
  const [refreshing, setRefreshing] = useState(false);
  const { isDark } = useTheme();
  const [showCreate, setShowCreate] = useState(false);
  const [newName, setNewName] = useState('');
  const [creating, setCreating] = useState(false);

  const fetchData = useCallback(async () => {
    try {
      const result = await knowledgeApi.list({ page: 1, page_size: 50 });
      const list = (result.items || []).map((item: any) => ({
        id: String(item.dataset_id || item.id || item.knowledge_id || ''),
        name: item.name || item.dataset_name || '未命名知识库',
        description: item.description || '',
        document_count: item.document_count || item.doc_count || 0,
        dataset_id: item.dataset_id || item.id,
      }));
      setItems(list);
    } catch (error) {
      console.error('Failed to fetch knowledge:', error);
    } finally {
      setLoading(false);
      setRefreshing(false);
    }
  }, []);

  useEffect(() => { fetchData(); }, [fetchData]);

  const onRefresh = () => {
    setRefreshing(true);
    fetchData();
  };

  const handleCreate = async () => {
    if (!newName.trim() || creating) return;
    setCreating(true);
    try {
      await knowledgeApi.create({ name: newName.trim() });
      setShowCreate(false);
      setNewName('');
      fetchData();
    } catch (e) {
      console.error('Create failed:', e);
    } finally {
      setCreating(false);
    }
  };

  const renderItem = ({ item }: { item: KnowledgeItem }) => (
    <View style={styles.card}>
      <View style={styles.cardIconWrap}>
        <Ionicons name="library-outline" size={22} color={Colors.primary} />
      </View>
      <View style={styles.cardContent}>
        <Text style={styles.cardTitle} numberOfLines={1}>{item.name}</Text>
        {item.description ? (
          <Text style={styles.cardDesc} numberOfLines={2}>{item.description}</Text>
        ) : null}
        <View style={styles.cardMeta}>
          <Ionicons name="document-text-outline" size={12} color={Colors.textTertiary} />
          <Text style={styles.cardMetaText}>{item.document_count} 篇文档</Text>
        </View>
      </View>
      <Ionicons name="chevron-forward" size={16} color={Colors.textTertiary} />
    </View>
  );

  if (loading) {
    return (
      <View style={styles.container}>
        <View style={styles.header}>
          <View style={{ width: 36 }} />
          <View style={{ height: 16, width: 80, backgroundColor: '#E8E8E8', borderRadius: 12 }} />
          <View style={{ width: 36 }} />
        </View>
        <SkeletonLoader type="list" visible={loading} />
      </View>
    );
  }

  return (
    <View style={styles.container}>
      <View style={styles.header}>
        <TouchableOpacity onPress={() => router.back()} style={styles.backBtn}>
          <Ionicons name="arrow-back" size={22} color={Colors.text} />
        </TouchableOpacity>
        <Text style={styles.headerTitle}>我的知识库</Text>
        <View style={{ width: 36 }} />
      </View>

      {items.length === 0 ? (
        <View style={styles.emptyContainer}>
          <Ionicons name="library-outline" size={56} color={Colors.textTertiary} />
          <Text style={styles.emptyText}>暂无知识库</Text>
          <Text style={styles.emptySubText}>暂未创建知识库，请在 sylab 平台添加</Text>
        </View>
      ) : (
        <FlatList
          data={items}
          keyExtractor={(item) => item.id}
          renderItem={renderItem}
          contentContainerStyle={{ padding: Spacing.md }}
          refreshControl={<RefreshControl refreshing={refreshing} onRefresh={onRefresh} colors={[Colors.primary]} />}
          showsVerticalScrollIndicator={false}
        />
      )}

      {/* Create Knowledge Base FAB */}
      <TouchableOpacity
        style={{ position: 'absolute', right: 20, bottom: 28, width: 56, height: 56, borderRadius: 28, backgroundColor: Colors.primary, justifyContent: 'center', alignItems: 'center', shadowColor: Colors.primary, shadowOffset: { width: 0, height: 4 }, shadowOpacity: 0.3, shadowRadius: 12, elevation: 6 }}
        onPress={() => setShowCreate(true)}
      >
        <Ionicons name="add" size={28} color="#fff" />
      </TouchableOpacity>

      {/* Create Modal */}
      {showCreate && (
        <View style={{ position: 'absolute', top: 0, left: 0, right: 0, bottom: 0, backgroundColor: 'rgba(0,0,0,0.4)', justifyContent: 'center', alignItems: 'center', zIndex: 100 }}>
          <View style={{ width: 300, backgroundColor: isDark ? '#1e293b' : '#fff', borderRadius: 16, padding: 20 }}>
            <Text style={{ fontSize: 17, fontWeight: '700', color: isDark ? '#f1f5f9' : '#0f172a', marginBottom: 16 }}>创建知识库</Text>
            <View style={{ backgroundColor: isDark ? '#334155' : '#f8fafc', borderRadius: 8, padding: 12, marginBottom: 16 }}>
              <input
                value={newName}
                onChange={(e: any) => setNewName(e.target.value)}
                placeholder="输入知识库名称"
                style={{ width: '100%', fontSize: 15, color: isDark ? '#f1f5f9' : '#0f172a', backgroundColor: 'transparent', border: 'none', outline: 'none' }}
                autoFocus
              />
            </View>
            <View style={{ flexDirection: 'row', gap: 12 }}>
              <TouchableOpacity onPress={() => { setShowCreate(false); setNewName(''); }} style={{ flex: 1, paddingVertical: 10, borderRadius: 8, backgroundColor: isDark ? '#334155' : '#f1f5f9', alignItems: 'center' }}>
                <Text style={{ color: isDark ? '#f1f5f9' : '#374151', fontWeight: '600' }}>取消</Text>
              </TouchableOpacity>
              <TouchableOpacity onPress={handleCreate} style={{ flex: 1, paddingVertical: 10, borderRadius: 8, backgroundColor: Colors.primary, alignItems: 'center', opacity: creating ? 0.6 : 1 }}>
                <Text style={{ color: '#fff', fontWeight: '600' }}>{creating ? '创建中...' : '创建'}</Text>
              </TouchableOpacity>
            </View>
          </View>
        </View>
      )}
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: Colors.backgroundSecondary },
  centerContainer: { flex: 1, justifyContent: 'center', alignItems: 'center', backgroundColor: Colors.backgroundSecondary },
  header: {
    flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between',
    paddingHorizontal: Spacing.md, paddingVertical: Spacing.sm,
    backgroundColor: '#fff', borderBottomWidth: 0.5, borderBottomColor: Colors.borderLight,
  },
  backBtn: { width: 36, height: 36, justifyContent: 'center', alignItems: 'center' },
  headerTitle: { fontSize: FontSize.lg, fontWeight: '700', color: Colors.text },
  card: {
    flexDirection: 'row', alignItems: 'center', backgroundColor: '#fff',
    borderRadius: BorderRadius.lg, padding: Spacing.md,
    marginBottom: Spacing.sm, ...Shadows.sm,
  },
  cardIconWrap: {
    width: 40, height: 40, borderRadius: 12,
    backgroundColor: 'rgba(96,48,255,0.08)',
    justifyContent: 'center', alignItems: 'center', marginRight: Spacing.md,
  },
  cardContent: { flex: 1 },
  cardTitle: { fontSize: FontSize.md, fontWeight: '600', color: Colors.text },
  cardDesc: { fontSize: FontSize.sm, color: Colors.textSecondary, marginTop: 2 },
  cardMeta: { flexDirection: 'row', alignItems: 'center', marginTop: 6, gap: 4 },
  cardMetaText: { fontSize: FontSize.xs, color: Colors.textTertiary },
  emptyContainer: { flex: 1, justifyContent: 'center', alignItems: 'center', paddingVertical: 80 },
  emptyText: { fontSize: FontSize.md, color: Colors.textTertiary, marginTop: Spacing.md },
  emptySubText: { fontSize: FontSize.sm, color: Colors.textTertiary, marginTop: 4 },
});
