import React, { useState, useEffect, useCallback, useRef } from 'react';
import { View, Text, FlatList, TouchableOpacity, StyleSheet, ActivityIndicator, RefreshControl, Alert, Modal, TextInput, Platform, Linking } from "react-native";
import { SafeAlert } from "../src/utils/safeAlert";
import { useRouter, useLocalSearchParams } from 'expo-router';
import { LinearGradient } from 'expo-linear-gradient';
import { Ionicons } from '@expo/vector-icons';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { useAuthStore } from '../src/store/auth';
import { creditsApi } from '../src/api/credits';
import { Colors, Spacing, BorderRadius, FontSize, Shadows } from '../src/constants/theme';

interface Transaction {
  id: string;
  action_type: string;
  amount: number;
  balance_after?: number;
  created_at: string;
  description?: string;
}

export default function CreditsScreen() {
  const router = useRouter();
  const insets = useSafeAreaInsets();
  const params = useLocalSearchParams<{ paid?: string }>();
  const { user } = useAuthStore();
  const [balance, setBalance] = useState(0);
  const [transactions, setTransactions] = useState<Transaction[]>([]);
  const [totalRecharged, setTotalRecharged] = useState(0);
  const [totalConsumed, setTotalConsumed] = useState(0);
  const [loading, setLoading] = useState(true);
  const [refreshing, setRefreshing] = useState(false);
  const [page, setPage] = useState(1);
  const [hasMore, setHasMore] = useState(true);
  const [loadingMore, setLoadingMore] = useState(false);

  // 在线充值
  const [showRechargeModal, setShowRechargeModal] = useState(false);
  const [plans, setPlans] = useState<Array<{ id: string; money: string; credits: string; label: string }>>([]);
  const [selectedPlan, setSelectedPlan] = useState<string>('');
  const [payType, setPayType] = useState<'alipay' | 'wxpay'>('alipay');
  const [paying, setPaying] = useState(false);
  const pollTimerRef = useRef<ReturnType<typeof setInterval> | null>(null);

  // 卡密兑换
  const [showRedeemModal, setShowRedeemModal] = useState(false);
  const [cardCode, setCardCode] = useState('');
  const [redeeming, setRedeeming] = useState(false);

  const fetchData = useCallback(async () => {
    if (!user?.id) return;
    try {
      const [balanceData, transData] = await Promise.all([
        creditsApi.getBalance(user.id),
        creditsApi.getTransactions(user.id, { page: 1, page_size: 20 }),
      ]);
      setBalance(Math.round(parseFloat(String(balanceData.balance || 0))));
      setTotalRecharged(Math.round(parseFloat(String(balanceData.total_recharged || 0))));
      setTotalConsumed(Math.round(parseFloat(String(balanceData.total_consumed || 0))));
      const items = (transData.items || []).map((t: any) => ({
        id: String(t.id || t.transaction_id || ''),
        action_type: t.type || t.action_type || t.action || 'unknown',
        amount: Math.round(parseFloat(String(t.amount || t.delta || 0))),
        balance_after: t.balance_after != null ? Math.round(parseFloat(String(t.balance_after))) : undefined,
        created_at: t.created_at || t.create_time || '',
        description: t.description || t.remark || '',
      }));
      setTransactions(items);
      setPage(1);
      setHasMore(items.length < (transData.total || 0));
    } catch (error) {
      console.error('Failed to fetch credits:', error);
    } finally {
      setLoading(false);
      setRefreshing(false);
    }
  }, [user]);

  useEffect(() => { fetchData(); }, [fetchData]);

  // 加载充值套餐
  const fetchPlans = useCallback(async () => {
    try {
      const res = await creditsApi.getPayPlans();
      setPlans(res.plans || []);
      if ((res.plans || []).length > 0) setSelectedPlan(res.plans[0].id);
    } catch (e) {
      console.error('load plans failed', e);
    }
  }, []);

  const openRecharge = () => {
    setShowRechargeModal(true);
    if (plans.length === 0) fetchPlans();
  };

  // 支付到账后轮询
  const startPolling = useCallback((outTradeNo: string) => {
    if (pollTimerRef.current) clearInterval(pollTimerRef.current);
    let tries = 0;
    const maxTries = 40; // 约 2 分钟
    pollTimerRef.current = setInterval(async () => {
      tries += 1;
      try {
        const r = await creditsApi.getPayStatus(outTradeNo);
        if (r.paid) {
          if (pollTimerRef.current) { clearInterval(pollTimerRef.current); pollTimerRef.current = null; }
          setShowRechargeModal(false);
          setPaying(false);
          SafeAlert.alert('充值成功', '积分已到账，感谢支持！');
          fetchData();
        }
      } catch (e) { /* 忽略单次轮询失败 */ }
      if (tries >= maxTries) {
        if (pollTimerRef.current) { clearInterval(pollTimerRef.current); pollTimerRef.current = null; }
        setPaying(false);
      }
    }, 3000);
  }, [fetchData]);

  useEffect(() => {
    return () => { if (pollTimerRef.current) clearInterval(pollTimerRef.current); };
  }, []);

  // 从支付页返回（return_url 带 paid=1）提示并刷新
  useEffect(() => {
    if (params.paid === '1') {
      fetchData();
      SafeAlert.alert('支付完成', '如积分未立即到账，请稍候，支付确认后会自动入账。');
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [params.paid]);

  const handlePay = async () => {
    if (!selectedPlan) { SafeAlert.alert('提示', '请选择充值套餐'); return; }
    if (!user?.id) return;
    setPaying(true);
    try {
      const res = await creditsApi.createPay(user.id, selectedPlan, payType);
      if (res.pay_url) {
        // 打开支付页（web 新标签；原生用 Linking 拉起）
        if (Platform.OS === 'web') {
          window.open(res.pay_url, '_blank');
        } else {
          await Linking.openURL(res.pay_url);
        }
        startPolling(res.out_trade_no);
        SafeAlert.alert('请完成支付', '已打开支付页面，完成付款后积分将自动到账。');
      } else {
        SafeAlert.alert('下单失败', res.message || '请稍后重试');
        setPaying(false);
      }
    } catch (error: any) {
      SafeAlert.alert('下单失败', error.response?.data?.detail || error.message || '网络错误');
      setPaying(false);
    }
  };

  const loadMore = async () => {
    if (!hasMore || loadingMore || !user?.id) return;
    setLoadingMore(true);
    try {
      const nextPage = page + 1;
      const data = await creditsApi.getTransactions(user.id, { page: nextPage, page_size: 20 });
      const items = (data.items || []).map((t: any) => ({
        id: String(t.id || t.transaction_id || ''),
        action_type: t.type || t.action_type || t.action || 'unknown',
        amount: Math.round(parseFloat(String(t.amount || t.delta || 0))),
        balance_after: t.balance_after != null ? Math.round(parseFloat(String(t.balance_after))) : undefined,
        created_at: t.created_at || t.create_time || '',
        description: t.description || t.remark || '',
      }));
      setTransactions(prev => [...prev, ...items]);
      setPage(nextPage);
      setHasMore(transactions.length + items.length < (data.total || 0));
    } catch (error) {
      console.error('Failed to load more:', error);
    } finally {
      setLoadingMore(false);
    }
  };

  const onRefresh = () => { setRefreshing(true); fetchData(); };

  const formatTime = (ts: string) => {
    if (!ts) return '';
    try {
      let d: Date;
      if (typeof ts === 'number') {
        // 秒级时间戳按 UTC 处理
        d = new Date(ts * 1000);
      } else {
        let s = String(ts).trim();
        // 后端返回的是 UTC 时间（MySQL 容器时区为 UTC），格式 "YYYY-MM-DD HH:MM:SS"
        // 不带时区标识时需手动补 Z 按 UTC 解析，再由 toLocaleString 转本地时区
        if (/^\d{4}-\d{2}-\d{2}[ T]\d{2}:\d{2}:\d{2}/.test(s) && !/[zZ]|[+-]\d{2}:?\d{2}$/.test(s)) {
          s = s.replace(' ', 'T') + 'Z';
        }
        d = new Date(s);
        if (isNaN(d.getTime())) d = new Date(ts);
      }
      return d.toLocaleString('zh-CN', { month: '2-digit', day: '2-digit', hour: '2-digit', minute: '2-digit' });
    } catch { return String(ts); }
  };

  const getActionLabel = (type: string) => {
    const map: Record<string, string> = {
      chat: '对话', consume: '积分消耗', workflow_run: '工作流', api_call: 'API调用',
      knowledge: '知识库', token_consumption: 'Token消耗', recharge: '充值',
      refund: '退款', adjustment: '调整', admin_adjust: '管理员调整', gift: '赠送', redeem: '卡密兑换',
      image_gen: '生图', video_gen: '生视频',
    };
    return map[type] || type;
  };

  const getActionIcon = (type: string) => {
    if (['recharge', 'refund', 'gift', 'redeem'].includes(type)) return 'cash-outline';
    if (type === 'workflow_run') return 'git-network-outline';
    if (type === 'api_call') return 'code-slash-outline';
    if (type === 'image_gen') return 'image-outline';
    if (type === 'video_gen') return 'videocam-outline';
    return 'chatbubble-ellipses-outline';
  };

  const handleRedeem = async () => {
    if (!cardCode.trim()) {
      SafeAlert.alert('提示', '请输入卡密');
      return;
    }
    if (!user?.id) return;
    setRedeeming(true);
    try {
      const result = await creditsApi.redeemCard(user.id, cardCode.trim());
      if (result.success) {
        SafeAlert.alert('兑换成功', `成功兑换 ${result.amount || ''} 积分`);
        setShowRedeemModal(false);
        setCardCode('');
        fetchData();
      } else {
        SafeAlert.alert('兑换失败', result.message || '卡密无效');
      }
    } catch (error: any) {
      SafeAlert.alert('兑换失败', error.response?.data?.message || error.message || '网络错误');
    } finally {
      setRedeeming(false);
    }
  };

  const renderItem = ({ item }: { item: Transaction }) => {
    // 后端 amount 对所有类型都存正数，消耗类按负数展示
    const isDeduct = ['consume', 'chat', 'token_consumption', 'workflow_run', 'api_call', 'knowledge', 'image_gen', 'video_gen'].includes(item.action_type);
    const signed = isDeduct ? -Math.abs(item.amount) : Math.abs(item.amount);
    const isPositive = signed > 0;
    return (
      <View style={styles.transCard}>
        <View style={[styles.transIconWrap, { backgroundColor: isPositive ? 'rgba(16,185,129,0.1)' : 'rgba(239,68,68,0.08)' }]}>
          <Ionicons name={getActionIcon(item.action_type) as any} size={18} color={isPositive ? '#10b981' : '#ef4444'} />
        </View>
        <View style={styles.transContent}>
          <Text style={styles.transType}>{getActionLabel(item.action_type)}</Text>
          {item.description ? <Text style={styles.transDesc} numberOfLines={1}>{item.description}</Text> : null}
          <Text style={styles.transTime}>{formatTime(item.created_at)}</Text>
        </View>
        <View style={styles.transAmountWrap}>
          <Text style={[styles.transAmount, { color: isPositive ? '#10b981' : Colors.danger }]}>
            {isPositive ? '+' : ''}{signed}
          </Text>
          {item.balance_after !== undefined && (
            <Text style={styles.transBalance}>余额 {item.balance_after}</Text>
          )}
        </View>
      </View>
    );
  };

  if (loading) {
    return (
      <View style={styles.centerContainer}>
        <ActivityIndicator size="large" color={Colors.primary} />
      </View>
    );
  }

  // 列表头部：余额卡 + 账户概览（卡密定价已挪入充值弹窗，让交易明细占满主区域）
  const renderListHeader = () => (
    <View>
      <LinearGradient colors={[Colors.gradientStart, Colors.gradientEnd]} style={styles.balanceCard}>
        <Text style={styles.balanceLabel}>当前积分余额</Text>
        <Text style={styles.balanceValue}>{balance}</Text>
        <View style={styles.balanceDivider} />
        <View style={styles.actionRow}>
          <TouchableOpacity style={[styles.actionBtn, styles.actionBtnPrimary]} onPress={openRecharge}>
            <Ionicons name="wallet-outline" size={18} color={Colors.primary} />
            <Text style={[styles.actionBtnText, { color: Colors.primary }]}>在线充值</Text>
          </TouchableOpacity>
          <TouchableOpacity style={styles.actionBtn} onPress={() => setShowRedeemModal(true)}>
            <Ionicons name="card-outline" size={18} color="#fff" />
            <Text style={styles.actionBtnText}>卡密兑换</Text>
          </TouchableOpacity>
        </View>
      </LinearGradient>

      {/* 总消耗汇总 */}
      <View style={styles.summaryCard}>
        <Text style={styles.summaryTitle}>账户概览</Text>
        <View style={styles.summaryRow}>
          <View style={styles.summaryItem}>
            <Ionicons name="arrow-down-circle-outline" size={18} color="#10b981" />
            <Text style={styles.summaryLabel}>累计充值</Text>
            <Text style={styles.summaryValue}>{totalRecharged.toLocaleString()}</Text>
          </View>
          <View style={styles.summaryDivider} />
          <View style={styles.summaryItem}>
            <Ionicons name="arrow-up-circle-outline" size={18} color="#ef4444" />
            <Text style={styles.summaryLabel}>累计消耗</Text>
            <Text style={styles.summaryValue}>{totalConsumed.toLocaleString()}</Text>
          </View>
          <View style={styles.summaryDivider} />
          <View style={styles.summaryItem}>
            <Ionicons name="wallet-outline" size={18} color={Colors.primary} />
            <Text style={styles.summaryLabel}>当前余额</Text>
            <Text style={[styles.summaryValue, { color: Colors.primary }]}>{balance.toLocaleString()}</Text>
          </View>
        </View>
      </View>

      {/* 交易明细标题 */}
      <View style={styles.transListHeader}>
        <Text style={styles.transListTitle}>交易明细</Text>
      </View>
    </View>
  );

  return (
    <View style={[styles.container, { paddingTop: insets.top }]}>
      <View style={styles.header}>
        <TouchableOpacity onPress={() => router.back()} style={styles.backBtn}>
          <Ionicons name="arrow-back" size={22} color={Colors.text} />
        </TouchableOpacity>
        <Text style={styles.headerTitle}>积分明细</Text>
        <View style={{ width: 36 }} />
      </View>

      {transactions.length === 0 && !loading ? (
        <FlatList
          data={[]}
          renderItem={() => null}
          ListHeaderComponent={renderListHeader}
          ListEmptyComponent={
            <View style={styles.emptyContainer}>
              <Ionicons name="wallet-outline" size={56} color={Colors.textTertiary} />
              <Text style={styles.emptyText}>暂无交易记录</Text>
            </View>
          }
          contentContainerStyle={{ paddingBottom: 40 }}
          refreshControl={<RefreshControl refreshing={refreshing} onRefresh={onRefresh} colors={[Colors.primary]} />}
          showsVerticalScrollIndicator={false}
        />
      ) : (
        <FlatList
          data={transactions}
          keyExtractor={(item) => item.id}
          renderItem={renderItem}
          ListHeaderComponent={renderListHeader}
          contentContainerStyle={{ paddingBottom: 40 }}
          refreshControl={<RefreshControl refreshing={refreshing} onRefresh={onRefresh} colors={[Colors.primary]} />}
          onEndReached={loadMore}
          onEndReachedThreshold={0.3}
          showsVerticalScrollIndicator={false}
          ListFooterComponent={loadingMore ? <ActivityIndicator style={{ padding: 16 }} color={Colors.primary} /> : null}
        />
      )}

      {/* 在线充值弹窗 */}
      <Modal visible={showRechargeModal} transparent animationType="fade">
        <View style={styles.modalOverlay}>
          <View style={[styles.modalContent, { maxWidth: 380 }]}>
            <Text style={styles.modalTitle}>在线充值</Text>
            <Text style={styles.modalDesc}>选择套餐，支持微信 / 支付宝，1元=1000积分</Text>

            {/* 套餐选择 */}
            <View style={styles.planGrid}>
              {plans.map((p) => {
                const active = selectedPlan === p.id;
                return (
                  <TouchableOpacity
                    key={p.id}
                    style={[styles.planItem, active && styles.planItemActive]}
                    onPress={() => setSelectedPlan(p.id)}
                  >
                    <Text style={[styles.planMoney, active && { color: '#fff' }]}>¥{p.money}</Text>
                    <Text style={[styles.planCredits, active && { color: 'rgba(255,255,255,0.85)' }]}>
                      {Number(p.credits).toLocaleString()} 积分
                    </Text>
                  </TouchableOpacity>
                );
              })}
            </View>

            {/* 支付方式 */}
            <View style={styles.payTypeRow}>
              <TouchableOpacity
                style={[styles.payTypeBtn, payType === 'wxpay' && styles.payTypeActiveWx]}
                onPress={() => setPayType('wxpay')}
              >
                <Ionicons name="logo-wechat" size={20} color={payType === 'wxpay' ? '#fff' : '#07c160'} />
                <Text style={[styles.payTypeText, payType === 'wxpay' && { color: '#fff' }]}>微信支付</Text>
              </TouchableOpacity>
              <TouchableOpacity
                style={[styles.payTypeBtn, payType === 'alipay' && styles.payTypeActiveAli]}
                onPress={() => setPayType('alipay')}
              >
                <Ionicons name="logo-alipay" size={20} color={payType === 'alipay' ? '#fff' : '#1677ff'} />
                <Text style={[styles.payTypeText, payType === 'alipay' && { color: '#fff' }]}>支付宝</Text>
              </TouchableOpacity>
            </View>

            <View style={styles.modalBtnRow}>
              <TouchableOpacity style={styles.modalCancelBtn} onPress={() => { setShowRechargeModal(false); setPaying(false); }}>
                <Text style={styles.modalCancelText}>取消</Text>
              </TouchableOpacity>
              <TouchableOpacity style={[styles.modalConfirmBtn, paying && { opacity: 0.6 }]} onPress={handlePay} disabled={paying}>
                {paying ? <ActivityIndicator size="small" color="#fff" /> : <Text style={styles.modalConfirmText}>立即支付</Text>}
              </TouchableOpacity>
            </View>
            <Text style={styles.payTip}>点击后跳转安全支付页面，付款成功积分自动到账</Text>
          </View>
        </View>
      </Modal>

      {/* 卡密兑换弹窗 */}
      <Modal visible={showRedeemModal} transparent animationType="fade">
        <View style={styles.modalOverlay}>
          <View style={styles.modalContent}>
            <Text style={styles.modalTitle}>卡密兑换</Text>
            <Text style={styles.modalDesc}>请输入卡密</Text>
            <TextInput
              style={styles.modalInput}
              placeholder="请输入卡密"
              value={cardCode}
              onChangeText={setCardCode}
              placeholderTextColor={Colors.textTertiary}
              autoCapitalize="none"
            />
            <View style={styles.modalBtnRow}>
              <TouchableOpacity style={styles.modalCancelBtn} onPress={() => { setShowRedeemModal(false); setCardCode(''); }}>
                <Text style={styles.modalCancelText}>取消</Text>
              </TouchableOpacity>
              <TouchableOpacity style={styles.modalConfirmBtn} onPress={handleRedeem} disabled={redeeming}>
                {redeeming ? <ActivityIndicator size="small" color="#fff" /> : <Text style={styles.modalConfirmText}>确认兑换</Text>}
              </TouchableOpacity>
            </View>
          </View>
        </View>
      </Modal>
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
  balanceCard: {
    margin: Spacing.md, borderRadius: BorderRadius.lg, padding: Spacing.lg, alignItems: 'center',
  },
  balanceLabel: { fontSize: FontSize.sm, color: 'rgba(255,255,255,0.7)' },
  balanceValue: { fontSize: 40, fontWeight: '800', color: '#fff', marginVertical: 4 },
  balanceDivider: { width: 40, height: 2, backgroundColor: 'rgba(255,255,255,0.3)', borderRadius: 1, marginVertical: 8 },
  actionRow: { flexDirection: 'row', gap: 12, marginTop: 12 },
  actionBtn: {
    flexDirection: 'row', alignItems: 'center', paddingHorizontal: 16, paddingVertical: 8,
    borderRadius: 20, backgroundColor: 'rgba(255,255,255,0.2)', gap: 6,
  },
  actionBtnText: { color: '#fff', fontSize: FontSize.sm, fontWeight: '600' },
  actionBtnPrimary: { backgroundColor: '#fff' },
  // 充值套餐
  planGrid: { flexDirection: 'row', flexWrap: 'wrap', gap: 8, marginBottom: 14 },
  planItem: {
    width: '31%', flexGrow: 1, backgroundColor: Colors.backgroundSecondary,
    borderRadius: BorderRadius.md, paddingVertical: 12, alignItems: 'center',
    borderWidth: 1.5, borderColor: 'transparent',
  },
  planItemActive: { backgroundColor: Colors.primary, borderColor: Colors.primary },
  planMoney: { fontSize: FontSize.lg, fontWeight: '800', color: Colors.text },
  planCredits: { fontSize: FontSize.xs, color: Colors.textSecondary, marginTop: 2 },
  payTypeRow: { flexDirection: 'row', gap: 10, marginBottom: 16 },
  payTypeBtn: {
    flex: 1, flexDirection: 'row', alignItems: 'center', justifyContent: 'center', gap: 6,
    paddingVertical: 12, borderRadius: BorderRadius.md, borderWidth: 1.5, borderColor: Colors.border,
  },
  payTypeActiveWx: { backgroundColor: '#07c160', borderColor: '#07c160' },
  payTypeActiveAli: { backgroundColor: '#1677ff', borderColor: '#1677ff' },
  payTypeText: { fontSize: FontSize.md, fontWeight: '600', color: Colors.text },
  payTip: { fontSize: FontSize.xs, color: Colors.textTertiary, textAlign: 'center', marginTop: 10 },
  transCard: {
    flexDirection: 'row', alignItems: 'center', backgroundColor: '#fff',
    borderRadius: BorderRadius.lg, padding: Spacing.md,
    marginBottom: Spacing.sm, ...Shadows.sm,
  },
  transIconWrap: {
    width: 36, height: 36, borderRadius: 10,
    justifyContent: 'center', alignItems: 'center', marginRight: Spacing.md,
  },
  transContent: { flex: 1 },
  transType: { fontSize: FontSize.md, fontWeight: '500', color: Colors.text },
  transDesc: { fontSize: FontSize.xs, color: Colors.textSecondary, marginTop: 2 },
  transTime: { fontSize: FontSize.xs, color: Colors.textTertiary, marginTop: 2 },
  transAmountWrap: { alignItems: 'flex-end' },
  transAmount: { fontSize: FontSize.lg, fontWeight: '700' },
  transBalance: { fontSize: FontSize.xs, color: Colors.textTertiary, marginTop: 2 },
  // Summary card
  summaryCard: {
    margin: Spacing.md, marginBottom: 0, backgroundColor: '#fff', borderRadius: BorderRadius.lg,
    padding: Spacing.md, ...Shadows.sm,
  },
  summaryTitle: { fontSize: FontSize.md, fontWeight: '700', color: Colors.text, marginBottom: Spacing.md },
  summaryRow: { flexDirection: 'row', alignItems: 'center' },
  summaryItem: { flex: 1, alignItems: 'center', gap: 4 },
  summaryLabel: { fontSize: FontSize.xs, color: Colors.textSecondary },
  summaryValue: { fontSize: FontSize.lg, fontWeight: '700', color: Colors.text },
  summaryDivider: { width: 1, height: 36, backgroundColor: Colors.borderLight, marginHorizontal: 4 },

  // Pricing card
  pricingCard: {
    margin: Spacing.md, marginBottom: 0, backgroundColor: '#fff', borderRadius: BorderRadius.lg,
    padding: Spacing.md, ...Shadows.sm,
  },
  pricingTitle: { fontSize: FontSize.md, fontWeight: '700', color: Colors.text, marginBottom: Spacing.md },
  pricingGrid: { flexDirection: 'row', flexWrap: 'wrap', gap: 8 },
  pricingItem: {
    flex: 1, minWidth: '28%', backgroundColor: Colors.backgroundSecondary, borderRadius: BorderRadius.md,
    padding: Spacing.sm, alignItems: 'center', marginVertical: 4,
  },
  pricingPrice: { fontSize: FontSize.xl, fontWeight: '800', color: Colors.primary },
  pricingCredits: { fontSize: FontSize.xs, color: Colors.textSecondary, marginTop: 2 },
  pricingNote: { fontSize: FontSize.xs, color: Colors.textTertiary, textAlign: 'center', marginTop: Spacing.sm },
  transListHeader: {
    paddingHorizontal: Spacing.md, paddingTop: Spacing.sm, paddingBottom: Spacing.xs,
  },
  transListTitle: { fontSize: FontSize.lg, fontWeight: '700', color: Colors.text },

  emptyContainer: { flex: 1, justifyContent: 'center', alignItems: 'center', paddingVertical: 80 },
  emptyText: { fontSize: FontSize.md, color: Colors.textTertiary, marginTop: Spacing.md },
  modalOverlay: {
    flex: 1, backgroundColor: 'rgba(0,0,0,0.5)', justifyContent: 'center', alignItems: 'center',
    padding: Spacing.lg,
  },
  modalContent: {
    backgroundColor: '#fff', borderRadius: BorderRadius.lg, padding: Spacing.lg,
    width: '100%', maxWidth: 360,
  },
  modalTitle: { fontSize: FontSize.lg, fontWeight: '700', color: Colors.text, textAlign: 'center', marginBottom: 4 },
  modalDesc: { fontSize: FontSize.sm, color: Colors.textSecondary, textAlign: 'center', marginBottom: 16 },
  modalInput: {
    borderWidth: 1, borderColor: Colors.border, borderRadius: BorderRadius.md,
    padding: Spacing.md, fontSize: FontSize.md, color: Colors.text, marginBottom: 12,
  },
  quickAmountRow: { flexDirection: 'row', flexWrap: 'wrap', gap: 8, marginBottom: 16 },
  quickAmountBtn: {
    paddingHorizontal: 16, paddingVertical: 8, borderRadius: 16,
    borderWidth: 1, borderColor: Colors.border,
  },
  quickAmountBtnActive: { backgroundColor: Colors.primary, borderColor: Colors.primary },
  quickAmountText: { fontSize: FontSize.sm, color: Colors.text },
  quickAmountTextActive: { color: '#fff' },
  modalBtnRow: { flexDirection: 'row', gap: 12 },
  modalCancelBtn: {
    flex: 1, paddingVertical: 12, borderRadius: BorderRadius.md,
    borderWidth: 1, borderColor: Colors.border, alignItems: 'center',
  },
  modalCancelText: { fontSize: FontSize.md, color: Colors.textSecondary },
  modalConfirmBtn: {
    flex: 1, paddingVertical: 12, borderRadius: BorderRadius.md,
    backgroundColor: Colors.primary, alignItems: 'center', justifyContent: 'center',
  },
  modalConfirmText: { fontSize: FontSize.md, color: '#fff', fontWeight: '600' },
});
