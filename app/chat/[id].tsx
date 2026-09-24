import React, { useEffect, useRef, useState } from 'react';
import { View, Text, FlatList, KeyboardAvoidingView, Platform, StyleSheet, ActivityIndicator, TouchableOpacity, Modal, Alert, Dimensions, StatusBar, TextInput, Animated, ScrollView, Linking, Keyboard } from "react-native";
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { SafeAlert } from "../../src/utils/safeAlert";
// expo-video dynamically imported to prevent native crash on iOS 26
import NetInfo from '@react-native-community/netinfo';
import { useLocalSearchParams, useNavigation, useRouter } from 'expo-router';
import { Colors, Spacing, BorderRadius, FontSize } from '../../src/constants/theme';
import { useTheme } from '../../src/hooks/useTheme';
import { useChatStore } from '../../src/store/chat';
import { useAuthStore } from '../../src/store/auth';
import { Storage } from '../../src/utils/storage';
import { chatApi } from '../../src/api/chat';
import { botApi } from '../../src/api/bot';
import { creditsApi } from '../../src/api/credits';
import { filesApi } from '../../src/api/files';
import { sendMessageStream } from '../../src/api/sse';
import { queueManager } from '../../src/queue/queueTaskManager';
import { AppEvents, subscribe } from '../../src/utils/events';
import { MessageBubble } from '../../src/components/MessageBubble';
import { ChatInput, getPendingFiles, clearPendingFiles } from '../../src/components/ChatInput';
import { EmptyState } from '../../src/components/EmptyState';
import { SkeletonLoader } from '../../src/components/SkeletonLoader';
import { TypingIndicator, getToolLabel } from '../../src/components/TypingIndicator';
import { GenerationPlaceholder } from '../../src/components/GenerationPlaceholder';
import { TaskStatusCard, getToolMeta } from '../../src/components/TaskStatusCard';
import DagProgressCard from '../../src/components/DagProgressCard';
import { Ionicons } from '@expo/vector-icons';
import type { ChatMessage } from '../../src/types/api';

// Safe Clipboard wrapper
const SafeClipboard = {
  setString: (text: string) => {
    try {
      const RN = require('react-native');
      if (RN.Clipboard && RN.Clipboard.setString) {
        RN.Clipboard.setString(text);
      }
    } catch (e) {
      console.warn('[Clipboard] Failed to copy:', e);
    }
  }
};





// Error Boundary to catch crashes and show error instead of white screen
class ChatErrorBoundary extends React.Component<
  { children: React.ReactNode },
  { hasError: boolean; error: string }
> {
  constructor(props: { children: React.ReactNode }) {
    super(props);
    this.state = { hasError: false, error: '' };
  }
  static getDerivedStateFromError(error: any) {
    return { hasError: true, error: String(error?.message || error) };
  }
  componentDidCatch(error: any, errorInfo: any) {
    console.error('[ChatErrorBoundary]', error, errorInfo);
  }
  render() {
    if (this.state.hasError) {
      return (
        <View style={{ flex: 1, justifyContent: 'center', alignItems: 'center', padding: 20, backgroundColor: '#fff' }}>
          <Ionicons name="alert-circle" size={48} color="#ef4444" />
          <Text style={{ fontSize: 18, fontWeight: 'bold', marginTop: 16, color: '#1f2937' }}>页面加载出错</Text>
          <Text style={{ fontSize: 13, color: '#6b7280', marginTop: 12, textAlign: 'center' }}>{this.state.error}</Text>
        </View>
      );
    }
    return this.props.children;
  }
}




// Module-level message tracker - survives component remounts
let _sessionMessages: any[] = [];
// Nuclear backup: Map<convId, messages[]> - survives any reset
const _messageBackup = new Map<string, any[]>();
// Dedup tracker for user messages: key = convId|content|2secBucket
const _recentUserMsgs = new Set<string>();
function _isDuplicateUserMsg(convId: string, text: string, timestamp: number): boolean {
  const secBucket = Math.floor(timestamp / 2000);
  const key = `${convId}|${(text || '').trim()}|${secBucket}`;
  if (_recentUserMsgs.has(key)) return true;
  _recentUserMsgs.add(key);
  if (_recentUserMsgs.size > 100) {
    const arr = Array.from(_recentUserMsgs);
    _recentUserMsgs.clear();
    arr.slice(-50).forEach(k => _recentUserMsgs.add(k));
  }
  return false;
}

// Helper: match credit transactions to assistant messages by time proximity
const matchTransactionsToMessages = (
  msgs: any[],
  transactions: any[],
  timeWindowMs: number = 60000
): Map<string, number> => {
  const costMap = new Map<string, number>();
  const assistantMsgs = msgs
    .filter((m: any) => m.role === 'assistant' && m.created_at)
    .map((m: any) => ({
      id: m.id,
      ts: Number(m.created_at) < 1e12 ? Number(m.created_at) * 1000 : Number(m.created_at),
    }))
    .sort((a: any, b: any) => a.ts - b.ts);

  const sortedTx = [...transactions]
    .filter((t: any) => t.created_at && t.cost > 0)
    .map((t: any) => ({
      id: t.id,
      ts: new Date(t.created_at).getTime(),
      cost: t.cost,
      used: false,
    }))
    .sort((a: any, b: any) => a.ts - b.ts);

  for (const aMsg of assistantMsgs) {
    let bestTx: any = null;
    let bestDiff = Infinity;
    for (const tx of sortedTx) {
      if (tx.used) continue;
      const diff = Math.abs(tx.ts - aMsg.ts);
      if (diff <= timeWindowMs && diff < bestDiff) {
        bestDiff = diff;
        bestTx = tx;
      }
    }
    if (bestTx) {
      costMap.set(aMsg.id, bestTx.cost);
      bestTx.used = true;
    }
  }
  return costMap;
};

const DEFAULT_BOT_ID = '7669580347859795968';
const DEFAULT_BOT_NAME = 'sylab AI';

// Video generation progress card - matches user screenshot style
function VideoGenerationOverlay({ status, progress }: { status: string; progress: number }) {
  const pulseAnim = React.useRef(new Animated.Value(1)).current;
  const barAnim = React.useRef(new Animated.Value(0)).current;
  const progressAnim = React.useRef(new Animated.Value(15)).current;

  React.useEffect(() => {
    const breathing = Animated.loop(
      Animated.sequence([
        Animated.timing(pulseAnim, { toValue: 1.08, duration: 1200, useNativeDriver: true }),
        Animated.timing(pulseAnim, { toValue: 1, duration: 1200, useNativeDriver: true }),
      ])
    );
    breathing.start();
    return () => breathing.stop();
  }, []);

  // Animated indeterminate bar that bounces up and down when progress is low
  React.useEffect(() => {
    if (progress < 50) {
      const bounce = Animated.loop(
        Animated.sequence([
          Animated.timing(barAnim, { toValue: 1, duration: 1500, useNativeDriver: true }),
          Animated.timing(barAnim, { toValue: 0, duration: 1500, useNativeDriver: true }),
        ])
      );
      bounce.start();
      return () => bounce.stop();
    }
  }, [progress < 50]);

  // Smoothly animate progress bar to actual progress value
  React.useEffect(() => {
    const targetHeight = Math.max(10, Math.min(90, progress || 15));
    Animated.timing(progressAnim, {
      toValue: targetHeight,
      duration: 500,
      useNativeDriver: false,
    }).start();
  }, [progress]);

  const statusText = status === 'polling' || status === 'queued' ? '正在生成中...'
    : status === 'processing' ? '视频渲染中...'
    : status === 'completed' ? '生成完成，加载中...'
    : '正在生成中...';

  const progressHeight = progressAnim;

  return (
    <View style={{ marginHorizontal: 12, marginVertical: 4 }}>
      <View style={{ flexDirection: 'row', backgroundColor: '#fff', borderRadius: 16, padding: 24, minHeight: 120, alignItems: 'center', justifyContent: 'center', shadowColor: '#000', shadowOffset: { width: 0, height: 1 }, shadowOpacity: 0.06, shadowRadius: 8, elevation: 2, position: 'relative' }}>
        {/* Center: icon + text */}
        <View style={{ alignItems: 'center' }}>
          <Animated.View style={{ transform: [{ scale: pulseAnim }] }}>
            <Ionicons name="videocam-outline" size={36} color="#9ca3af" />
          </Animated.View>
          <Text style={{ marginTop: 12, color: '#9ca3af', fontSize: 15, fontWeight: '500' }}>{statusText}</Text>
          {progress > 0 && progress < 100 && (
            <Text style={{ marginTop: 4, color: '#8B5CF6', fontSize: 12, fontWeight: '600' }}>{progress}%</Text>
          )}
        </View>
        {/* Right side: animated vertical progress bar */}
        <View style={{ position: 'absolute', right: 20, top: '50%', transform: [{ translateY: -30 }], width: 4, height: 60, backgroundColor: '#f3f4f6', borderRadius: 2, overflow: 'hidden' }}>
          {progress < 50 ? (
            <Animated.View style={{
              width: '100%',
              height: '40%',
              backgroundColor: '#8B5CF6',
              borderRadius: 2,
              position: 'absolute',
              bottom: barAnim.interpolate({
                inputRange: [0, 1],
                outputRange: ['0%', '60%'],
              }),
            }} />
          ) : (
            <Animated.View style={{
              width: '100%',
              height: progressHeight.interpolate({
                inputRange: [10, 90],
                outputRange: ['10%', '90%'],
                extrapolate: 'clamp',
              }),
              backgroundColor: '#8B5CF6',
              borderRadius: 2,
              position: 'absolute',
              bottom: 0,
            }} />
          )}
        </View>
      </View>
      <Text style={{ textAlign: 'center', marginTop: 10, color: '#d1d5db', fontSize: 12 }}>视频任务耗时较长，完成后会通知您</Text>
    </View>
  );
}

// Completed video card - inline video playback
function CompletedVideoCard({ videoUrl, isDark }: { videoUrl: string; isDark: boolean }) {
  if (!videoUrl) return null;
  if (Platform.OS === 'web') {
    return (
      <View style={{ marginHorizontal: 12, marginVertical: 6 }}>
        <View style={{ backgroundColor: isDark ? '#1e293b' : '#fff', borderRadius: 16, padding: 12, shadowColor: '#000', shadowOffset: { width: 0, height: 1 }, shadowOpacity: 0.06, shadowRadius: 8, elevation: 2 }}>
          <View style={{ flexDirection: 'row', alignItems: 'center', marginBottom: 8 }}>
            <Ionicons name="videocam" size={20} color="#8B5CF6" />
            <Text style={{ color: isDark ? '#f1f5f9' : '#1f2937', fontSize: 14, fontWeight: '600', marginLeft: 8 }}>视频已生成</Text>
          </View>
          <video src={videoUrl} controls style={{ width: '100%', maxWidth: 480, borderRadius: 12, backgroundColor: '#000' }} />
        </View>
      </View>
    );
  }
  return <NativeVideoPlayer videoUrl={videoUrl} isDark={isDark} />;
}

// Error boundary for native video player
class NativeVideoErrorBoundary extends React.Component<
  { children: React.ReactNode },
  { hasError: boolean }
> {
  constructor(props: { children: React.ReactNode }) {
    super(props);
    this.state = { hasError: false };
  }
  static getDerivedStateFromError() {
    return { hasError: true };
  }
  render() {
    if (this.state.hasError) {
      return (
        <View style={{ marginHorizontal: 12, marginVertical: 6, padding: 20, backgroundColor: '#f3f4f6', borderRadius: 16, alignItems: 'center' }}>
          <Ionicons name="videocam-off-outline" size={28} color="#9ca3af" />
          <Text style={{ color: '#6b7280', fontSize: 13, marginTop: 8 }}>视频播放不可用</Text>
        </View>
      );
    }
    return this.props.children;
  }
}

function NativeVideoPlayer({ videoUrl, isDark }: { videoUrl: string; isDark: boolean }) {
  const [videoModule, setVideoModule] = useState<{ useVideoPlayer: any; VideoView: any } | null>(null);
  const [loadError, setLoadError] = useState(false);

  useEffect(() => {
    if (!videoUrl || Platform.OS === 'web') return;
    let mounted = true;
    import('expo-video').then(mod => {
      if (mounted) setVideoModule({ useVideoPlayer: mod.useVideoPlayer, VideoView: mod.VideoView });
    }).catch(() => {
      if (mounted) setLoadError(true);
    });
    return () => { mounted = false; };
  }, [videoUrl]);

  if (!videoUrl || typeof videoUrl !== 'string') return null;
  if (loadError) {
    return (
      <View style={{ marginHorizontal: 12, marginVertical: 6, padding: 20, backgroundColor: '#f3f4f6', borderRadius: 16, alignItems: 'center' }}>
        <Ionicons name="videocam-off-outline" size={28} color="#9ca3af" />
        <Text style={{ color: '#6b7280', fontSize: 13, marginTop: 8 }}>视频播放不可用</Text>
      </View>
    );
  }
  if (!videoModule) {
    return (
      <View style={{ marginHorizontal: 12, marginVertical: 6, padding: 20, backgroundColor: isDark ? '#1e293b' : '#fff', borderRadius: 16, alignItems: 'center' }}>
        <ActivityIndicator size="small" color="#8B5CF6" />
        <Text style={{ color: isDark ? '#94a3b8' : '#6b7280', fontSize: 13, marginTop: 8 }}>加载视频播放器...</Text>
      </View>
    );
  }
  return (
    <NativeVideoErrorBoundary>
      <NativeVideoPlayerInner videoUrl={videoUrl} isDark={isDark} useVideoPlayer={videoModule.useVideoPlayer} VideoView={videoModule.VideoView} />
    </NativeVideoErrorBoundary>
  );
}

function NativeVideoPlayerInner({ videoUrl, isDark, useVideoPlayer, VideoView }: { videoUrl: string; isDark: boolean; useVideoPlayer: any; VideoView: any }) {
  const player = useVideoPlayer(videoUrl, (p: any) => { p.loop = false; });
  return (
    <View style={{ marginHorizontal: 12, marginVertical: 6 }}>
      <View style={{ backgroundColor: isDark ? '#1e293b' : '#fff', borderRadius: 16, padding: 12, shadowColor: '#000', shadowOffset: { width: 0, height: 1 }, shadowOpacity: 0.06, shadowRadius: 8, elevation: 2 }}>
        <View style={{ flexDirection: 'row', alignItems: 'center', marginBottom: 8 }}>
          <Ionicons name="videocam" size={20} color="#8B5CF6" />
          <Text style={{ color: isDark ? '#f1f5f9' : '#1f2937', fontSize: 14, fontWeight: '600', marginLeft: 8 }}>视频已生成</Text>
        </View>
        <VideoView player={player} style={{ width: '100%', height: 220, borderRadius: 12, backgroundColor: '#000' }} contentFit="contain" allowsFullscreen allowsPictureInPicture />
      </View>
    </View>
  );
}

// Strip technical info (task_id, API URLs) from AI message for display
const sanitizeVideoContent = (text: string): string => {
  if (!text) return text;
  let result = text;
  // Remove any line containing task_id or task_xxx
  result = result.replace(/^.*task_[A-Za-z0-9_]{10,}.*$/gm, '');
  // Remove lines containing 任务ID
  result = result.replace(/^[^\n]*任务ID[^\n]*/gm, '');
  // Remove lines containing 状态：
  result = result.replace(/^[^\n]*状态[：:][^\n]*/gm, '');
  // Remove lines containing 进度：xx% or 进度 xx%
  result = result.replace(/^[^\n]*进度[\s：:]*\d+%[^\n]*/gm, '');
  // Remove 当前状态 lines
  result = result.replace(/^当前状态[：:][^\n]*$/gm, '');
  // Remove **最终状态：** header
  result = result.replace(/[*]*最终状态[*]*[：:][^\n]*/gi, '');
  // Remove **任务信息：** header
  result = result.replace(/[*]*任务信息[*]*[：:][^\n]*/gi, '');
  // Remove **视频正在生成中** and similar markdown status lines
  result = result.replace(/^[^\n]*\*\*视频正在生成中[^\n]*/gm, '');
  // Remove **视频已生成完成** lines
  result = result.replace(/^[^\n]*\*\*视频已生成完成[^\n]*/gm, '');
  // Remove **关于视频链接：** lines
  result = result.replace(/^[^\n]*\*\*关于视频链接[^\n]*/gm, '');
  // Remove emoji+bold status lines like ✅**xxx** or ️**xxx**
  result = result.replace(/^[\s]*[✅⚠️📋🎬]+\s*\*\*[^*]+\*\*[^\n]*/gm, '');
  // Remove --- separator lines
  result = result.replace(/^---+$/gm, '');
  // Remove empty ** lines
  result = result.replace(/^\*\*\s*$/gm, '');
  // Remove empty lines left behind
  result = result.replace(/\n{3,}/g, '\n\n');
  return result.trim();
};



// Strip emoji from AI text content (system prompt says no emoji but model doesn't always comply)
const stripEmoji = (text: string): string => {
  if (!text) return text;
  return text.replace(/[\u{1F300}-\u{1F9FF}]|[\u{2600}-\u{26FF}]|[\u{2700}-\u{27BF}]|[\u{1F000}-\u{1F02F}]|[\u{1F0A0}-\u{1F0FF}]|[\u{1F100}-\u{1F1FF}]|[\u{1F200}-\u{1F2FF}]|[\u{1F600}-\u{1F64F}]|[\u{1F680}-\u{1F6FF}]|[\u{1F900}-\u{1F9FF}]|\u{FE0F}|\u{200D}/gu, '');
};

const stripMarkdown = (text: string): string => {
  if (!text) return "";
  return text
    .replace(/<img\s[^>]*alt="([^"]*)"[^>]*>/gi, (_, alt) => alt ? `[图片: ${alt}]` : "[图片]")
    .replace(/<img\s[^>]*>/gi, "[图片]")
    .replace(/<[^>]+>/g, "")
    .replace(/#{1,6}\s*/g, "")
    .replace(/\*\*(.+?)\*\*/g, "$1")
    .replace(/\*(.+?)\*/g, "$1")
    .replace(/`(.+?)`/g, "$1")
    .replace(/\[(.+?)\]\(.+?\)/g, "$1")
    .replace(/!\[.*?\]\(.+?\)/g, "")
    .replace(/^[-*+]\s+/gm, "")
    .replace(/\n+/g, " ")
    .trim();
};

const formatTime = (ts: any): string => {
  if (!ts) return "";
  const num = Number(ts);
  if (isNaN(num) || num === 0) return "";
  const ms = num < 1e12 ? num * 1000 : num;
  const date = new Date(ms);
  if (isNaN(date.getTime())) return "";
  const now = new Date();
  const isToday = date.toDateString() === now.toDateString();
  const isThisYear = date.getFullYear() === now.getFullYear();
  if (isToday) {
    const h = date.getHours().toString().padStart(2, "0");
    const m = date.getMinutes().toString().padStart(2, "0");
    return `${h}:${m}`;
  }
  if (isThisYear) {
    const mo = (date.getMonth() + 1).toString().padStart(2, "0");
    const d = date.getDate().toString().padStart(2, "0");
    return `${mo}/${d}`;
  }
  const y = date.getFullYear();
  const mo = (date.getMonth() + 1).toString().padStart(2, "0");
  const d = date.getDate().toString().padStart(2, "0");
  return `${y}/${mo}/${d}`;
};

function ChatDetailScreenInner() {
  const { id, bot_id, prompt } = useLocalSearchParams<{ id: string; bot_id?: string; prompt?: string }>();
  const navigation = useNavigation();
  const router = useRouter();
  const flatListRef = useRef<FlatList>(null);
  // [FIX scroll 乱跳] 用“粘滞”状态：用户一旦上翻就锁定在原位置，只有他自己滚回底部/点回底/发消息才解除。
  // 不再用定时器在停顿后自动交还控制权（旧逻辑停手 1.5s 后后台轮询就把视图拽回底部）。
  const isNearBottomRef = useRef(true);
  const userScrollingRef = useRef(false);   // 粘滞：用户手动上翻后保持 true
  const userScrollTimerRef = useRef<any>(null);
  const didInitialScrollRef = useRef(false); // 首屏仅滚底一次，之后 onLayout 不再强行滚底
  // [FIX 进入聊天页底部持续跳动 2026-09-24] maintainVisibleContentPosition 本质是为
  // “顶部插入旧消息时保持位置”，与首屏 scrollToEnd（到底部）目标相反；官方文档明确
  // 启用时对内容插入会产生跳跃/卡顿。因此首屏定位阶段先不启用 MVCP，等滚底稳定后再开，
  // 既消除首屏抖动，又保留后续上拉加载历史时的位置保持。
  const [enableMvcp, setEnableMvcp] = useState(false);
  // [FIX2 抖动] 单一合并的“跟随到底”调度：一帧内多次内容/布局变化只滚一次；
  // 流式内容长高阶段不滚（避免边追边抖），仅在跟随态且确有新内容时滚。
  const followRafRef = useRef<any>(null);
  const followPendingRef = useRef(false);
  const requestFollow = (opts?: { force?: boolean }) => {
    const force = !!(opts && opts.force);
    // 用户正在上翻阅读：绝不跟随
    if (userScrollingRef.current && !force) return;
    if (!isNearBottomRef.current && !force) return;
    if (followPendingRef.current) return;
    followPendingRef.current = true;
    if (followRafRef.current) { try { cancelAnimationFrame(followRafRef.current); } catch (_) {} }
    followRafRef.current = requestAnimationFrame(() => {
      followPendingRef.current = false;
      followRafRef.current = null;
      if (!force && (userScrollingRef.current || !isNearBottomRef.current)) return;
      try { flatListRef.current?.scrollToEnd({ animated: false }); } catch (_) {}
    });
  };
  const markUserScrolling = (duration?: number) => {
    // duration 仅用于很短的松手惯性缓冲；位置判定以 handleScroll 为准
    userScrollingRef.current = true;
    if (userScrollTimerRef.current) clearTimeout(userScrollTimerRef.current);
    if (duration) {
      userScrollTimerRef.current = setTimeout(() => {
        // 惯性结束后：若已经回到底部附近才解除跟随锁；否则继续锁定（关键：不自动解锁）
        if (isNearBottomRef.current) userScrollingRef.current = false;
      }, duration);
    }
  };
  // 仅在用户位于底部附近且未手动上翻时自动跟随（统一走合并调度，杜绝一帧多次滚动打架）
  const autoFollowToBottom = (_animated = false) => {
    requestFollow();
  };

  // [v105 滚动修复 v2] 流式内容持续长高时的"平滑贴底"：
  // 1. 节流 250ms（原 120ms 仍会抖动）
  // 2. 去掉 trailing 定时器（它会在 130ms 后再触发一次，导致双重滚动）
  // 3. 严格遵守粘滞锁：用户上翻阅读期间一次都不跟
  const lastFollowTsRef = useRef(0);
  const requestFollowStream = () => {
    if (userScrollingRef.current || !isNearBottomRef.current) return;
    const now = Date.now();
    if (now - lastFollowTsRef.current >= 250) {
      lastFollowTsRef.current = now;
      requestFollow();
    }
  };

  const { user, patToken, isRestoring } = useAuthStore();
  const userName = (() => {
    const n = user?.name || '';
    return /^\d+$/.test(n.trim()) ? '用户' : (n || '用户');
  })();
  const userAvatar = user?.avatar_url || '';
  const {
    messages, isStreaming, streamingContent, streamingMessageId,
    toolCalls, error,
    setMessages, appendDelta, appendToolCall, finishStreaming,
    clearStreaming, setError, startStreaming,
    activityStatus, generatingType,
    setActivityStatus,
  } = useChatStore();

  // Auto-scroll when messages array changes (only if user is near bottom)
  const messagesLength = messages.length;
  useEffect(() => {
    if (messagesLength <= 0) return;
    // 首屏/进入会话：只滚底一次
    if (!didInitialScrollRef.current) {
      didInitialScrollRef.current = true;
      requestAnimationFrame(() => {
        flatListRef.current?.scrollToEnd({ animated: false });
        setTimeout(() => {
          flatListRef.current?.scrollToEnd({ animated: false });
          // 滚底序列完成、位置稳定后再启用 MVCP（此时才允许它接管后续位置保持）
          setEnableMvcp(true);
        }, 120);
      });
      return;
    }
    // 之后仅在跟随态（用户在底部且未上翻锁）才跟随；后台轮询/排序变化不打扰阅读
    if (isNearBottomRef.current && !userScrollingRef.current) {
      requestFollow();
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [messagesLength]);

  // [FIX] Removed redundant streamingContent scroll effect - onContentSizeChange handles auto-scroll

  const [showScrollBtn, setShowScrollBtn] = useState(false);
  const inFlightSendRef = useRef<string | null>(null);

  const scrollToBottom = () => {
    // 用户主动回底/发消息：恢复跟随模式
    userScrollingRef.current = false;
    if (userScrollTimerRef.current) clearTimeout(userScrollTimerRef.current);
    isNearBottomRef.current = true;
    try { flatListRef.current?.scrollToEnd({ animated: true }); } catch (_) {}
    requestFollow({ force: true });
  };

  // [FIX] Web 端 onEndReached 不可靠，改用 onScroll 检测滚动到顶部触发 loadMore
  const handleScroll = (event: any) => {
    // Detect scroll near top to trigger loadMoreMessages (all platforms)
    if (event?.nativeEvent) {
      const { contentOffset, contentSize, layoutMeasurement } = event.nativeEvent;
      if (contentOffset && contentSize && layoutMeasurement) {
        const nearTop = contentOffset.y < 100;
        if (nearTop && hasMore && !loadingMoreRef.current) {
          loadMoreMessages();
        }
      }
    }
    const { layoutMeasurement, contentOffset, contentSize } = event.nativeEvent;
    const distanceFromBottom = contentSize.height - contentOffset.y - layoutMeasurement.height;
    const near = distanceFromBottom < 120;
    isNearBottomRef.current = near;
    // [FIX scroll] 用户自己滚回了底部：解除上翻锁定，恢复跟随
    if (near && userScrollingRef.current) {
      userScrollingRef.current = false;
      if (userScrollTimerRef.current) clearTimeout(userScrollTimerRef.current);
    }
    const shouldShow = distanceFromBottom > 240;
    setShowScrollBtn(prev => prev !== shouldShow ? shouldShow : prev);
  };



  const [loading, setLoading] = useState(true);
  const [botName, setBotName] = useState(DEFAULT_BOT_NAME);
  const [botAvatar, setBotAvatar] = useState('');
  const [conversationId, setConversationId] = useState<string | null>(null);

  // === wave4d-fix2: 内部消息判定 + 消息指纹（过滤/去重共用）===
  const _isInternalMsg = (m: any): boolean => {
    try {
      if (!m || !m.id) return true;
      const c = (m.content == null ? '' : String(m.content)).trim();
      if (!c) return true;
      if (c.includes('generate_answer_finish')) return true;
      if (/^【DAG|^【TIMER|^【定时|^【CRON/.test(c)) return true; // DAG/定时内部触发气泡
      if ((m.role || '') !== 'user') {
        if (/^\{"index":\d+,"id":"call_/.test(c)) return true;  // function call
        if (/^\{"code":\d+,"msg":/.test(c)) return true;        // tool result wrapper
        if (c.includes('"function"') && c.includes('"arguments"')) return true;
      }
      return false;
    } catch (e) { return false; }
  };
  const _isVisibleMsg = (m: any): boolean => {
    if (!m || !m.id) return false;
    const c = (m.content == null ? '' : String(m.content)).trim();
    if ((m.role || '') === 'user') {
      if (!c) return false;
      if (/^【DAG|^【TIMER|^【定时|^【CRON/.test(c)) return false;
      return true;
    }
    return !_isInternalMsg(m);
  };
  const _mkey = (m: any): string => {
    try { return (m.role || '') + '|' + (m.content == null ? '' : String(m.content)).replace(/\s+/g, ' ').trim().slice(0, 120); }
    catch (e) { return (m.role || ''); }
  };

  // === [FIX 消息闪一下消失] 服务端历史 vs 本地列表合并 ===
  // 原则：用户已经在屏幕上看到的 AI 回复，绝不允许被后台轮询/历史刷新删掉。
  // 服务端消息为权威全量保留；本地用户消息服务端未收录则保留；本地 assistant 回复
  // 只要不与服务端任一回复重复就保留（后端瞬时未落库时，本地流式回复是唯一副本），
  // 内容归一化（去 TRAE_REF/空白/emoji）后按头/尾指纹去重，最终按时间排序。
  const _normContent = (m: any): string => {
    try {
      return ((m == null || m.content == null ? '' : String(m.content))
        .replace(/\[\$TRAE_REF\]\([^)]*\)/g, '')
        .replace(/[\u{1F000}-\u{1FAFF}\u{2600}-\u{27BF}\u{FE00}-\u{FE0F}\u{200D}]/gu, '')
        .replace(/\s+/g, ' ').trim());
    } catch (e) { return (m && m.content == null ? '' : String((m && m.content) || '')).trim(); }
  };
  const _mergeWithServerMsgs = (cur: any[], serverMsgs: any[]): any[] => {
    const srv: any[] = serverMsgs || [];
    const local: any[] = cur || [];
    const serverIds = new Set(srv.map((m: any) => m && m.id).filter(Boolean));
    const isInternal = (m: any) => /^【DAG|^【TIMER|^【定时|^【CRON/.test((((m && m.content) || '') + '').trim());
    const srvSigs = new Set<string>();
    const normSrv = new Map<any, string>();
    for (const m of srv) {
      if (!m || (m.role || '') !== 'assistant') continue;
      const c = _normContent(m);
      normSrv.set(m, c);
      if (c.length >= 40) srvSigs.add('H:' + c.slice(0, 60));
      if (c.length >= 8) srvSigs.add('HT:' + c.slice(0, 60) + '...' + c.slice(-60));
    }
    const localKeep = local.filter((m: any) => {
      if (!m) return false;
      if (serverIds.has(m.id)) return false;
      if (isInternal(m)) return false;
      const role = m.role || '';
      if (role === 'user') return true;
      if (role !== 'assistant') return false;
      const c = _normContent(m);
      if (!c) return false;
      for (const [sm, sc] of normSrv.entries()) {
        if (sc === c) return false;
        if (sc.length >= 40 && c.length >= 40 && sc.slice(0, 60) === c.slice(0, 60)) return false;
      }
      if (c.length >= 40 && srvSigs.has('H:' + c.slice(0, 60))) return false;
      if (c.length >= 8 && srvSigs.has('HT:' + c.slice(0, 60) + '...' + c.slice(-60))) return false;
      return true;
    });
    const merged = [...localKeep, ...srv];
    const seen = new Set<string>();
    const dedup = merged.filter((m: any) => {
      const k = _mkey(m);
      if (seen.has(k)) return false;
      seen.add(k);
      return true;
    });
    dedup.sort((a: any, b: any) => (_ts(a && a.created_at) || 0) - (_ts(b && b.created_at) || 0));
    return dedup;
  };

  // === wave4d-fix2 background idle poll ===
  // 后台 DAG/定时任务跑完，停留页面也自动刷出最终播报；服务端删除的内部气泡也会同步移除。
  useEffect(() => {
    let stopped = false;
    let timer: any = null;
    const tick = async () => {
      if (stopped) return;
      const cid = (conversationId || id || '') as string;
      const st = useChatStore.getState();
      if (!cid) { schedule(); return; }
      if (st.isStreaming) { schedule(); return; }
      try {
        if ((Platform as any).OS === 'web' && typeof document !== 'undefined' && document.visibilityState === 'hidden') { schedule(); return; }
      } catch (e) {}
      try {
        const result: any = await chatApi.getMessages(cid, { page_num: 1, page_size: 50 });
        if (stopped) return;
        const msgs = (result.items || [])
          .filter(_isVisibleMsg)
          .map((m: any) => ({ ...m, content: (m.content || '').replace(/\[\$TRAE_REF\]\([^)]*\)/g, '') }));
        msgs.reverse();
        const cur = useChatStore.getState().messages;
        // [FIX 消息消失] 本地已渲染的 AI 回复不再被后台轮询丢弃（后端瞬时未落库时本地是唯一副本）
        const dedup = _mergeWithServerMsgs(cur, msgs);
        // [FIX 10秒跳动] 后台轮询是稳态高频操作：仅当“可见消息的稳定身份集合”真的新增/删除时才替换数组。
        // 同一批消息的属性(时间戳/字段)刷新不触发 setMessages，避免 FlatList 全量重渲染+Markdown重排导致列表周期性跳动。
        const visCur = cur.filter(_isVisibleMsg);
        const _idSet = (arr: any[]) => {
          const ids = new Set<string>();
          for (const m of arr) { if (m && m.id != null) ids.add('id:' + m.id); }
          // 无 id 的本地临时消息退化为内容指纹
          for (const m of arr) { if (m && (m.id == null)) ids.add('fp:' + _mkey(m)); }
          return ids;
        };
        const curIds = _idSet(visCur);
        const newIds = _idSet(dedup);
        let changed = curIds.size !== newIds.size;
        if (!changed) { for (const k of newIds) { if (!curIds.has(k)) { changed = true; break; } } }
        if (!changed) { for (const k of curIds) { if (!newIds.has(k)) { changed = true; break; } } }
        if (changed) { useChatStore.getState().setMessages(dedup); }
      } catch (e) {
        try { console.warn('[POLL] tick failed:', e && (e as any).message || e); } catch (_) {}
      }
      schedule();
    };
    const schedule = () => { if (!stopped) { timer = setTimeout(tick, 10000); } };
    timer = setTimeout(tick, 6000);
    return () => { stopped = true; if (timer) clearTimeout(timer); };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [conversationId, id]);

  const [currentBotId, setCurrentBotId] = useState<string>(
    bot_id || DEFAULT_BOT_ID
  );
  const [initError, setInitError] = useState<string | null>(null);
  const [debugError, setDebugError] = useState<string | null>(null);
  // Bot selector
  const [showBotSelector, setShowBotSelector] = useState(false);
  const [availableBots, setAvailableBots] = useState<Array<{id: string; name: string; icon_url?: string}>>([]);
  // Video task polling
  const [videoTasks, setVideoTasks] = useState<Map<string, {taskId: string; status: string; url?: string; progress?: number; msgId?: string}>>(new Map());
  // Failed messages for retry
  const [failedMessages, setFailedMessages] = useState<Set<string>>(new Set());

  // Long press action menu
  const [longPressMenu, setLongPressMenu] = useState<{
    visible: boolean;
    message: ChatMessage | null;
  }>({ visible: false, message: null });

  // Quote state
  const [quotedMessage, setQuotedMessage] = useState<ChatMessage | null>(null);

  // Message queue for continuous sending
  const messageQueueRef = useRef<Array<{ text: string; files?: any[]; fileIds?: string[] }>>([]);
  // Track which user message each AI reply is responding to
  const lastUserMsgRef = useRef<ChatMessage | null>(null);
  const pendingFilesRef = useRef<Array<{blob: Blob, name: string, type: string}>>([]);
  // Track when last tool completed, to keep "X完成" visible briefly
  const lastToolCompleteRef = useRef<number>(0);

  // Pagination
  const [page, setPage] = useState(1);
  const [hasMore, setHasMore] = useState(true);
  const [loadingMore, setLoadingMore] = useState(false);
  const loadingMoreRef = useRef(false);

  // Network status
  const [isOffline, setIsOffline] = useState(false);
  const { isDark, Colors: C } = useTheme();

  // Message search
  const [showSearch, setShowSearch] = useState(false);
  const [searchQuery, setSearchQuery] = useState('');

  // [FIX2 抖动] 稳定的列表数据：搜索为空时直接复用 messages 引用，避免每渲染新建数组导致整列重建。
  const visibleMessages = React.useMemo(() => {
    if (!searchQuery) return messages as any[];
    const q = searchQuery.toLowerCase();
    const seen = new Set<string>();
    return (messages as any[]).filter((m: any) => {
      if (!m || !m.id) return false;
      if (!((m.content || '') + '').toLowerCase().includes(q)) return false;
      const _k = m.role + '|' + (m.content || '').trim().slice(0, 100) + '|' + Math.floor(Number(m.created_at) / (m.role === 'user' ? 5000 : 3000));
      if (seen.has(_k)) return false;
      seen.add(_k);
      return true;
    });
  }, [messages, searchQuery]);

  // Message costs tracking
  const [messageCosts, setMessageCosts] = useState<Map<string, number>>(() => new Map());
  const costsVersionRef = useRef(0);


  useEffect(() => {
    const unsub = NetInfo.addEventListener(state => {
      setIsOffline(!state.isConnected);
    });
    return () => unsub();
  }, []);

  // Keyboard height tracking for iOS input avoidance
  const [keyboardHeight, setKeyboardHeight] = useState(0);
  const insets = useSafeAreaInsets();
  useEffect(() => {
    const onKbWillShow = (e: any) => {
      // 键盘即将弹起：跟随态提前贴底，避免 FlatList 被键盘顶起时可视区停在旧位置
      if (!userScrollingRef.current && isNearBottomRef.current) {
        requestAnimationFrame(() => requestFollow({ force: false }));
      }
      if (e && e.endCoordinates) setKeyboardHeight(e.endCoordinates.height);
    };
    const showSub = Keyboard.addListener('keyboardDidShow', (e) => {
      setKeyboardHeight(e.endCoordinates.height);
      // Android 没有 keyboardWillShow：didShow 时补一次贴底
      if (Platform.OS !== 'ios' && !userScrollingRef.current && isNearBottomRef.current) {
        requestAnimationFrame(() => requestFollow({ force: false }));
      }
    });
    const willShowSub = Platform.OS === 'ios' ? Keyboard.addListener('keyboardWillShow' as any, onKbWillShow as any) : null;
    const hideSub = Keyboard.addListener('keyboardDidHide', () => {
      setKeyboardHeight(0);
    });
    return () => { showSub.remove(); hideSub.remove(); if (willShowSub) willShowSub.remove(); };
  }, []);


  // [FIX2 抖动] 流式“内容长高”阶段不主动滚：气泡在列表底部 footer 内自然撑高，
  // 反复 scrollToEnd 会与浏览器/原生滚动位打架产生上下抖。仅在“刚进入流式”且跟随态时贴一次底。
  useEffect(() => {
    if (useChatStore.getState().isStreaming) {
      if (!userScrollingRef.current && isNearBottomRef.current) requestFollow();
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [isStreaming]);

  const lastLoadMoreRef = useRef(0);
  const loadMoreMessages = async () => {
    const now = Date.now();
    if (loadingMoreRef.current || !hasMore || isNewChat) return;
    if (lastLoadMoreRef.current > 0 && now - lastLoadMoreRef.current < 2000) return;
    lastLoadMoreRef.current = now;
    const convId = conversationId || id || "";
    if (!convId) return;
    
    loadingMoreRef.current = true;
    setLoadingMore(true);
    try {
      const nextPage = page + 1;
      const result = await chatApi.getMessages(convId, { page_num: nextPage, page_size: 50 });
      const msgs = (result.items || []).filter(_isVisibleMsg).map((m: any) => ({...m, content: m.content?.replace(/\[\$TRAE_REF\]\([^)]*\)/g, "")})).reverse();
      if (msgs.length === 0) {
        setHasMore(false);
      } else {
        const prev = useChatStore.getState().messages;
        const validMsgs = msgs.filter((m: any) => m && m.id);
        const existingIds = new Set(prev.map(m => m.id).filter(Boolean));
        // Also dedup by content+time for local temp msgs vs server msgs
        const existingKeys = new Set(prev.map((m: any) => {
          const _t = _ts(m.created_at);
          return (m.role || '') + '|' + (m.content || '').trim().slice(0, 200) + '|' + Math.floor(_t / 1000);
        }));
        const newMsgs = validMsgs.filter((m: any) => {
          if (existingIds.has(m.id)) return false;
          const _t = _ts(m.created_at);
          const _k = (m.role || '') + '|' + (m.content || '').trim().slice(0, 200) + '|' + Math.floor(_t / 1000);
          if (existingKeys.has(_k)) return false;
          return true;
        });
        if (newMsgs.length > 0) {
          setMessages([...newMsgs, ...prev]);
        }
        setPage(nextPage);
      }
    } catch (e) {
      console.warn('[Chat] loadMore failed:', e);
    } finally {
      loadingMoreRef.current = false;
      setLoadingMore(false);
    }
  };




  const isNewChat = !!bot_id && bot_id !== id;

  useEffect(() => {
    navigation.setOptions({
      title: botName,
      headerBackTitle: '', headerBackButtonDisplayMode: 'minimal',
      headerRight: () => (
        <View style={{ flexDirection: 'row', alignItems: 'center', gap: 10, marginRight: 8 }}>
          <TouchableOpacity onPress={() => { fetchBots(); setShowBotSelector(true); }}>
            <Ionicons name="swap-horizontal" size={20} color="#6030ff" />
          </TouchableOpacity>
          <TouchableOpacity onPress={() => setShowSearch(!showSearch)}>
            <Ionicons name={showSearch ? "close" : "search"} size={22} color="#6030ff" />
          </TouchableOpacity>
          <TouchableOpacity onPress={() => router.push(`/projects/${conversationId || id}`)}>
            <Ionicons name="folder" size={22} color="#6030ff" />
          </TouchableOpacity>
        </View>
      ),
    });
  }, [botName, conversationId, id]);

  // Track last processed conversation to avoid re-fetching when user changes
  const lastProcessedConvRef = useRef<string | null>(null);

  useEffect(() => {
    // [QM] 全局任务管理器持有连接：切会话/离开不再中断流。
    // 仅重置本页流式态；若本会话有活跃任务，attach effect 会重新灌入快照。
    if (useChatStore.getState().isStreaming) {
      console.log('[Chat] Resetting stale streaming state on conversation switch');
      useChatStore.getState().clearStreaming();
    }

    let cancelled = false;

    const init = async () => {
      console.log('[Chat] Init called, id:', id, 'user:', !!user, 'isRestoring:', isRestoring);
      if (!id) { 
        
        return; 
      }
      // Wait for auth to restore
      if (isRestoring || !user) {
        setLoading(true);
        // Safety timeout - dont get stuck forever
        setTimeout(() => setLoading(false), 8000);
        return;
      }
      // Skip if already loaded this conversation
      if (lastProcessedConvRef.current === id) { 
      
        return; 
      }
      lastProcessedConvRef.current = id;
      

      // Clear old messages when switching conversations
      setMessages([]);
      _sessionMessages = [];
      _messageBackup.clear();
      _recentUserMsgs.clear();
      setPage(1);
      setHasMore(true);

      try {
        if (isNewChat) {
          setCurrentBotId(bot_id!);
          const conv = await chatApi.createConversation(bot_id!, '', user.id);
          const convId = conv?.id || conv?.conversation_id || '';
          if (!cancelled) {
            if (convId) {
              setConversationId(convId);
              setMessages([]);
              _sessionMessages = [];
            } else {
              setInitError('创建对话失败');
            }
          }
        } else {
          setConversationId(id);
          const result = await chatApi.getMessages(id, { page_num: 1, page_size: 50 });
          const msgs = (result.items || []).filter(_isVisibleMsg).map((m: any) => ({...m, content: m.content?.replace(/\[\$TRAE_REF\]\([^)]*\)/g, "")}));
          msgs.reverse();
          if (!cancelled) {
            
              // Dedup: merge server msgs with any existing local msgs (e.g., just-sent user message)
            const _existing = useChatStore.getState().messages;
            const _serverIds = new Set(msgs.map((m: any) => m.id).filter(Boolean));
            // Dedup local msgs by content+time against server msgs (local temp IDs won't match server IDs)
            const _serverKeys = new Set(msgs.map((m: any) => {
              const _t = _ts(m.created_at);
              return (m.role || '') + '|' + (m.content || '').trim().slice(0, 200) + '|' + Math.floor(_t / 1000);
            }));
            const _localOnly = _existing.filter((m: any) => {
              if (_serverIds.has(m.id)) return false;
              const _t = _ts(m.created_at);
              const _k = (m.role || '') + '|' + (m.content || '').trim().slice(0, 200) + '|' + Math.floor(_t / 1000);
              if (_serverKeys.has(_k)) return false;
              return true;
            });
            const _merged = [..._localOnly, ...msgs];
            // Also dedup by content+role for same timestamp (local temp msgs vs server msgs)
            const _seen = new Set<string>();
            const _deduped = _merged.filter((m: any) => {
              const _msts = _ts(m.created_at);
              const key = m.role + '|' + (m.content || '').trim().slice(0, 100) + '|' + Math.floor(_msts / 1000);
              if (_seen.has(key)) return false;
              _seen.add(key);
              return true;
            });
            setMessages(_deduped);
            _sessionMessages = _deduped;
            _messageBackup.set(id as string, _deduped);
            // Batch query transactions for historical cost matching
            try {
              const txResult = await creditsApi.getTransactions(user.id, { page: 1, page_size: 50 });
              const txItems = txResult.items || [];
              if (txItems.length > 0) {
                const costMap = matchTransactionsToMessages(msgs, txItems, 120000);
                if (costMap.size > 0) {
                  setMessageCosts(costMap);
                }
              }
            } catch (e) {
              console.warn("[Chat] Failed to load transaction costs:", e);
            }
          }
        }
      } catch (e: any) {
        console.error("[Chat] Init failed:", e?.message, e?.response?.status, e?.stack);
          setDebugError(e?.message || String(e));
        if (!cancelled) {
          setMessages([]);
          _sessionMessages = [];
          setInitError(e?.message || '加载消息失败');
        }
      } finally {
        if (!cancelled) {
          
          setLoading(false);
        }
      }
    };
    
    init();
    return () => {
      cancelled = true;
      // [QM] 离开聊天页不中断全局任务连接（流由 queueManager 持有）
    };
  }, [id, user, isRestoring]);


  // === [QM] 进入聊天页：接入全局任务管理器 ===
  // 离开页面不卸载任务：SSE 由全局单例持有；切后台/杀掉 APP 重开由 manager 自动恢复。
  useEffect(() => {
    // [QM-FIX] attach 目标用 conversationId||id：新会话创建后 router.replace，
    // 真实会话 id 才生效；仅用路由 id 会和 task.conversationId 对不上，导致
    // 状态/正文事件被丢弃（实时状态卡一直停在"正在思考理解"）。
    const attachId = (conversationId || id || '') as string;
    if (!attachId) return;

    // [FIX 消息消失] 抽取历史拉取+合并：onComplete 和 onReloadHistory 共用。
    // 流式结束后调用，把服务端已落库的最终 AI 回复合并进消息列表，避免临时气泡清空后消息"消失"。
    let reloading = false;
    const reloadHistoryOnce = (target: string) => {
      if (!target || reloading) return;
      reloading = true;
      chatApi.getMessages(target, { page_num: 1, page_size: 50 }).then((result: any) => {
        const msgs = (result.items || [])
          .filter(_isVisibleMsg)
          .map((m: any) => ({ ...m, content: (m.content || '').replace(/\[\$TRAE_REF\]\([^)]*\)/g, '') }));
        msgs.reverse();
        const existing = useChatStore.getState().messages;
        // [FIX 消息消失] 保留本地已渲染的 AI 回复；服务端同内容自动去重替换，绝不删用户已见回复
        const dedup = _mergeWithServerMsgs(existing, msgs);
        setMessages(dedup);
      }).catch(() => {}).finally(() => { setTimeout(() => { reloading = false; }, 800); });
    };

    queueManager.detach(attachId);
    queueManager.attach(attachId, {
      onComplete: (chatId: string, convId: string) => {
        try {
          // [FIX 消息消失] 流式结束后立即拉一次服务端历史，把最终 AI 回复落进消息列表。
          // 否则结束瞬间临时流式气泡被清空、正式消息未写入，要重进页面才出现。
          const reloadTarget = convId || ((conversationId || id || '') as string);
          if (reloadTarget) {
            setTimeout(() => { reloadHistoryOnce(reloadTarget); }, 400);
          }
          // 刷新成本展示（拉最近交易匹配本条消息）
          const userId = user?.id || '';
          if (userId) {
            creditsApi.getTransactions(userId, { page: 1, page_size: 3 }).then((txResult: any) => {
              const txItems = txResult.items || [];
              const now = Date.now();
              for (const tx of txItems) {
                const txTime = new Date(tx.created_at).getTime();
                if (Math.abs(txTime - now) < 30000 && tx.cost > 0) {
                  setMessageCosts((prev: Map<string, number>) => {
                    const next = new Map(prev);
                    next.set(chatId, tx.cost);
                    return next;
                  });
                  break;
                }
              }
            }).catch(() => {});
          }
          // 继续发送队列里排队的下一条消息
          setTimeout(() => {
            const check = () => {
              if (!useChatStore.getState().isStreaming) { processQueue(); }
              else { setTimeout(check, 200); }
            };
            check();
          }, 300);
        } catch (e) {}
      },
      onError: (msg: string, status?: number, code?: string) => {
        try {
          // 401 未登录：直接引导去登录页（强制登录策略）
          if (status === 401 || code === 'auth_required') {
            setError('请先登录后再使用');
            setTimeout(() => { try { router.replace('/login'); } catch (e) {} }, 800);
            return;
          }
          // Message already delivered; task error != send failure
          const friendly = msg && msg !== 'Internal Server Error' ? msg : '任务执行异常，请重新发送指令';
          setError(friendly);
        } catch (e) {}
      },
      // [patch 2026-09-09] 任务已在服务端结束（完成/失败/中转缓存过期）：
      // 静默结束转圈并刷新会话历史——结果永久保存在服务端历史里
      onReloadHistory: (convId: string) => {
        try {
          const target = convId || ((conversationId || id || '') as string);
          if (target) reloadHistoryOnce(target);
        } catch (e) {}
      },
    });
    // 同步全局视频任务状态
    const syncVideo = () => {
      setVideoTasks(new Map(queueManager.getVideoTasks()) as any);
    };
    syncVideo();
    const unsubVideo = subscribe(AppEvents.CHAT_VIDEO_UPDATED, syncVideo);
    return () => {
      unsubVideo();
      queueManager.detach(attachId);
      // [QM] 不清理 streaming store：离开后任务继续，返回时 attach 重建状态
    };
  }, [id, conversationId]);

  // Auto-scroll useEffect removed to prevent infinite scroll loop

  const handleLongPress = React.useCallback((message: ChatMessage) => {
    setLongPressMenu({ visible: true, message });
  }, []);

  const closeMenu = () => {
    setLongPressMenu({ visible: false, message: null });
  };

  const handleCopy = () => {
    if (!longPressMenu.message) return;
    const plainText = stripMarkdown(longPressMenu.message.content || '');
    closeMenu();
    if (Platform.OS === 'web') {
      // Web端统一用prompt兜底，兼容iOS Safari HTTP等所有环境
      setTimeout(() => {
        window.prompt('复制消息（长按文字可手动复制）：', plainText);
      }, 100);
    } else {
      SafeClipboard.setString(plainText);
      SafeAlert.alert('已复制');
    }
  };

  const handleQuote = () => {
    if (!longPressMenu.message) return;
    setQuotedMessage(longPressMenu.message);
    closeMenu();
  };



  const processQueue = async () => { console.log("[Queue] processQueue called, queueLen:", messageQueueRef.current.length, "isStreaming:", useChatStore.getState().isStreaming, "convId:", conversationId || id);
    if (messageQueueRef.current.length === 0 || useChatStore.getState().isStreaming) { console.log("[Queue] EXIT: len=0 or streaming"); return; }
    const next = messageQueueRef.current.shift()!;
    await doSend(next.text, next.files, next.fileIds, (conversationId || id || "") as string, true);
  };

  const effectiveConvId = conversationId || id || '';

  const handleSend = async (text: string, _files?: any[], fileIds?: string[]) => {
    // 强制登录：未登录不允许发起对话，直接跳登录页
    if (!useAuthStore.getState().user?.id) {
      setError('请先登录后再使用');
      try { router.replace('/login'); } catch (e) {}
      return;
    }
    if (!patToken) return; if (!text.trim() && (!fileIds || fileIds.length === 0)) return;

    // [FIX scroll] 用户主动发消息：恢复跟随并滚到底部，以便看到新回复
    userScrollingRef.current = false;
    if (userScrollTimerRef.current) clearTimeout(userScrollTimerRef.current);
    isNearBottomRef.current = true;
    setTimeout(() => { flatListRef.current?.scrollToEnd({ animated: true }); }, 350);

    // Ensure conversationId is set; create conversation if needed
    let currentConvId = conversationId || id;
    if (!currentConvId) {
      try {
        const conv = await chatApi.createConversation(currentBotId, '', user?.id || '');
        if (conv?.id) {
          currentConvId = conv.id;
          setConversationId(conv.id);
          // Update URL to the new conversation
          router.replace(`/chat/${conv.id}`);
        } else {
          console.error('[Chat] Failed to create conversation for quote');
          return;
        }
      } catch (e) {
        console.error('[Chat] Create conversation failed:', e);
        return;
      }
    }
    
    // If already streaming, queue the message
    if (useChatStore.getState().isStreaming) {
      messageQueueRef.current.push({ text, files: _files, fileIds }); console.log("[Queue] message QUEUED:", (text || "").substring(0,30), "total:", messageQueueRef.current.length);
      // Still add user message to display immediately
      const qHasImage = _files && _files.some((f: any) => (f.type || '').toLowerCase().startsWith('image/'));
      let qFirstImg = '';
      if (qHasImage && _files) {
        const qFirstFile = _files.find((f: any) => (f.type || '').toLowerCase().startsWith('image/'));
        qFirstImg = qFirstFile ? (qFirstFile.url || '') : '';
      }
      const userMsg: ChatMessage = {
        id: `msg_${Date.now()}`,
        conversation_id: effectiveConvId,
        role: 'user',
        type: qHasImage && qFirstImg ? 'image_url' : 'text',
        content: qHasImage && qFirstImg ? `[IMG:${qFirstImg}]${text}` : text,
        content_type: qHasImage && qFirstImg ? 'image_url' : 'text',
        created_at: String(Date.now()),
        updated_at: String(Date.now()),
      };
      lastUserMsgRef.current = userMsg;
      {
        const _prevA = useChatStore.getState().messages;
        const _qContentDup = _prevA.some(m => m.role === user && m.content === userMsg.content && Math.abs(_ts(m.created_at) - _ts(userMsg.created_at)) < 10000);
        if (!_isDuplicateUserMsg(effectiveConvId, userMsg.content, Number(userMsg.created_at)) && !_qContentDup && !_prevA.some(m => m.id === userMsg.id)) {
          setMessages([..._prevA, userMsg]);
          _sessionMessages = [..._sessionMessages, userMsg];
        }
      }
      return;
    }
    
    await doSend(text, _files, fileIds, currentConvId as string);
  };

  // Normalize any timestamp to milliseconds (server uses seconds, local uses ms)
  const _ts = (t: any): number => {
    const n = Number(t);
    if (!n || isNaN(n)) return 0;
    return n < 1e12 ? n * 1000 : n;
  };

  const doSend = async (text: string, _files?: any[], fileIds?: string[], forcedConvId?: string, skipUserMsg?: boolean) => {
    const effectiveConvId = forcedConvId || conversationId || id || '';

    // Dedupe in-flight identical sends (double tap / race between queue + direct send)
    const sendFingerprint = effectiveConvId + '|' + (text || '').trim() + '|' + (fileIds ? fileIds.join(',') : '') + '|' + Date.now().toString().slice(0, -3);
    if (inFlightSendRef.current === sendFingerprint) {
      console.log('[Chat] doSend skipped duplicate in-flight:', sendFingerprint);
      return;
    }
    inFlightSendRef.current = sendFingerprint;
    setTimeout(() => { if (inFlightSendRef.current === sendFingerprint) inFlightSendRef.current = null; }, 4000);

    let finalContent = text;
    if (quotedMessage) {
      const quoteRole = quotedMessage.role === 'user' ? '我' : 'AI';
      const quotePreview = stripMarkdown(quotedMessage.content || '').substring(0, 300);
      finalContent = `[引用${quoteRole}的消息]：「${quotePreview}」\n\n${text}`;
      setQuotedMessage(null);
    }

    if (!skipUserMsg) {
    // Detect if there are image files attached
    const hasImageFiles = _files && _files.some((f: any) => (f.type || '').toLowerCase().startsWith('image/'));
    let firstImageUrl = '';
    if (hasImageFiles && _files) {
      const firstImgFile = _files.find((f: any) => (f.type || '').toLowerCase().startsWith('image/'));
      firstImageUrl = firstImgFile ? (firstImgFile.url || '') : '';
    }
    const userMsg: ChatMessage = {
      id: `msg_${Date.now()}`,
      conversation_id: effectiveConvId,
      role: 'user',
      type: hasImageFiles && firstImageUrl ? 'image_url' : 'text',
      content: hasImageFiles && firstImageUrl ? `[IMG:${firstImageUrl}]${finalContent}` : finalContent,
      content_type: hasImageFiles && firstImageUrl ? 'image_url' : 'text',
      created_at: String(Date.now()),
      updated_at: String(Date.now()),
    };
    lastUserMsgRef.current = userMsg;
    const _prevB = useChatStore.getState().messages;
    const _isContentDup = _prevB.some(m => m.role === 'user' && m.content === userMsg.content && Math.abs(_ts(m.created_at) - _ts(userMsg.created_at)) < 10000);
    if (!_isDuplicateUserMsg(effectiveConvId, userMsg.content, Number(userMsg.created_at)) && !_isContentDup) {
      if (!_prevB.some(m => m.id === userMsg.id)) {
        setMessages([..._prevB, userMsg]);
        _sessionMessages = [..._sessionMessages, userMsg];
      }
    }
      // Save to nuclear backup immediately (dedup by content)
      const backupKey = effectiveConvId || 'pending';
      const existing = _messageBackup.get(backupKey) || [];
      if (!existing.some(m => m.role === 'user' && m.content === userMsg.content)) {
        _messageBackup.set(backupKey, [...existing, userMsg]);
      }
    }
    startStreaming();

    // Track SSE state for onError guard (prevents queue starting when SSE is actually working)
    let sseReceivedData = false;
    let sseCompleted = false;

    const aiContent = finalContent;

    // Build additional_messages: combine files + text into object_string for multimodal support
    const additionalMsgs: Array<{ role: string; content: string; content_type: string }> = [];
    // Collect image URLs from _files (uploaded via /user-upload)
    const imageUrls: string[] = [];
    if (_files && _files.length > 0) {
      for (const f of _files) {
        const u = (f as any).url || '';
        if (u && u.startsWith('http')) imageUrls.push(u);
      }
    }
    const realFileIds: string[] = [];
    if (fileIds) {
      for (const fid of fileIds) {
        if (fid && fid.startsWith('http')) {
          imageUrls.push(fid);
        } else if (fid) {
          realFileIds.push(fid);
        }
      }
    }

    if (imageUrls.length > 0 || realFileIds.length > 0) {
      const contentParts: Array<{ type: string; text?: string; file_id?: string; file_url?: string }> = [];
      for (const imgUrl of imageUrls) {
        contentParts.push({ type: 'image', file_url: imgUrl });
      }
      for (const fid of realFileIds) {
        contentParts.push({ type: 'file', file_id: fid });
      }
      contentParts.push({ type: 'text', text: aiContent || '请分析这张图片' });
      additionalMsgs.push({
        role: 'user',
        content: JSON.stringify(contentParts),
        content_type: 'object_string',
      });
    } else {
      additionalMsgs.push({
        role: 'user',
        content: aiContent,
        content_type: 'text',
      });
    }

    // === LOCAL CAPTURE: immune to component remounts and store resets ===
    const localUserContent = finalContent;
    const localConvId = conversationId;
    let localAiAccum = "";

    // === Chat Queue PRIMARY mode: task runs on the server and survives
    // app/background disconnects. This submit promise is awaited by the
    // queue stream adapter below; the task persists server-side either way. ===
    // [QM] 任务交由全局队列管理器：离开页面/切后台/杀掉 APP 均不中断；
    // delta/工具事件/完成收尾(落库/命名/附件)/视频轮询全部由 manager 全局处理
    queueManager.startTask(
      {
        bot_id: currentBotId,
        user_id: user?.id || '',
        conversation_id: effectiveConvId || undefined,
        additional_messages: additionalMsgs,
        stream: true,
        auto_save_history: true,
        bearer_token: patToken || '',
        mode: 'primary',
      },
      patToken || '',
      localUserContent || ''
    );
  };

  const handleRetry = async (failedMsgId: string) => {
    const failedMsg = messages.find(m => m.id === failedMsgId);
    if (!failedMsg) return;
    setFailedMessages(prev => { const next = new Set(prev); next.delete(failedMsgId); return next; });
    // Remove the failed message
    const _cur = useChatStore.getState().messages;
    setMessages(_cur.filter(m => m.id !== failedMsgId));
    // Resend
    await handleSend(failedMsg.content || '');
  };

  const handleStop = () => {
    // [QM] 取消全局队列任务（服务端任务一并取消）
    queueManager.cancelForConv((conversationId || id || '') as string);
  };

  // Fetch available bots
  const fetchBots = async () => {
    try {
      const result = await botApi.list({ page: 1, page_size: 20 });
      setAvailableBots(result.items.map((b: any) => ({
        id: b.id,
        name: b.name || 'Unknown',
        icon_url: b.icon_url || b.avatar_url || '',
      })));
      // Set avatar for current bot
      const currentBot = result.items.find((b: any) => b.id === currentBotId);
      if (currentBot) {
        setBotAvatar(currentBot.icon_url || currentBot.avatar_url || '');
      }
    } catch (e) {
      console.warn('[Chat] Failed to fetch bots:', e);
    }
  };

  const handleBotSwitch = async (newBotId: string, newBotName: string) => {
    setCurrentBotId(newBotId);
    setBotName(newBotName);
    const matched = availableBots.find((b: any) => b.id === newBotId);
    if (matched) setBotAvatar(matched.icon_url || '');
    setShowBotSelector(false);
    // Create a new conversation with the new bot
    try {
      const userId = user?.id || '';
      if (!userId) { try { router.replace('/login'); } catch (e) {} return; }
      const conv = await chatApi.createConversation(newBotId, '', userId);
      if (conv?.id) {
        setConversationId(conv.id);
        setMessages([]);
        _sessionMessages = [];
        router.replace(`/chat/${conv.id}?bot_id=${newBotId}` as any);
      }
    } catch (e) {
      console.warn('[Chat] Failed to create conversation with new bot:', e);
    }
  };

  if (debugError) {
    return (
      <View style={styles.container}>
        <View style={{flex: 1, justifyContent: 'center', alignItems: 'center', padding: 20}}>
          <Ionicons name="alert-circle" size={48} color="#ef4444" />
          <Text style={{fontSize: 16, fontWeight: 'bold', marginTop: 16, color: '#1f2937'}}>Error</Text>
          <Text style={{fontSize: 12, color: '#6b7280', marginTop: 8, textAlign: 'center'}}>{debugError}</Text>
          <TouchableOpacity onPress={() => { setDebugError(null); init(); }} style={{marginTop: 16, padding: 10, backgroundColor: '#8B5CF6', borderRadius: 8}}>
            <Text style={{color: '#fff', fontSize: 14, fontWeight: '600'}}>Retry</Text>
          </TouchableOpacity>
        </View>
      </View>
    );
  }

  if (loading) {
    return (
      <View style={styles.container}>
        <View style={{backgroundColor: '#ff9900', padding: 8, alignItems: 'center'}}>
        </View>
        <SkeletonLoader type="chat-detail" visible={loading} />
      </View>
    );
  }

  const renderItem = ({ item }: { item: ChatMessage }) => {
    if (!item || !item.id) return null;
    // Filter empty/partial messages (both user and assistant)
    const _raw = (item.content || '').trim();
    if (!_raw) return null;
    if (item.role === 'assistant') {
      // Also filter stale AI messages that are only whitespace, newlines, or emoji
      const _clean = _raw.replace(/[\u00a0\u200b\ufeff]/g, '').replace(/[\u{1F300}-\u{1F9FF}\u{2600}-\u{26FF}\u{2700}-\u{27BF}\u{FE0F}\u{200D}]/gu, '');
      if (_clean.length === 0) return null;
    }
    const isFailed = failedMessages.has(item.id);
    
    // Check if this message has an active video task
    const hasActiveVideoTask = Array.from(videoTasks.values()).some(t => 
      t.msgId === item.id && (t.status === 'polling' || t.status === 'queued' || t.status === 'processing')
    );
    const activeTask = hasActiveVideoTask ? Array.from(videoTasks.values()).find(t => t.msgId === item.id) : null;
    
    // Sanitize message content if it contains video task technical info
    const hasVideoTechInfo = item.role === 'assistant' && /^(\*\*)?(task_id|task_[A-Za-z0-9]{10,}|视频已生成完成|视频正在生成中|正在尝试生成视频|视频生成服务暂时不可用|关于视频链接|替代方案|当前状态[：:]|最终状态[：:]|任务信息[：:]|\*\*视频|\*\*任务|\*\*最终|\*\*当前)/i.test((item.content || '').split('\n')[0]);
    const displayItem = hasVideoTechInfo ? { ...item, content: sanitizeVideoContent(item.content) } : item;
    
    return (
      <View>
        <MessageBubble 
          message={displayItem}
          userName={userName}
          botName={botName}
          botAvatar={botAvatar}
          userAvatar={userAvatar}
          isDark={isDark}
          onLongPress={handleLongPress} 
          cost={messageCosts.get(item.id)}
        />
        {activeTask && <VideoGenerationOverlay status={activeTask.status} progress={activeTask.progress || 0} />}
        {(() => {
          const completedVideoTask = Array.from(videoTasks.values()).find(t => 
            t.msgId === item.id && t.status === 'completed' && t.url
          );
          return completedVideoTask ? <CompletedVideoCard videoUrl={completedVideoTask.url} isDark={isDark} /> : null;
        })()}
        {isFailed && item.role === 'user' && (
          <View style={{ flexDirection: 'row', justifyContent: 'flex-end', paddingHorizontal: Spacing.md, marginTop: -2, marginBottom: 4 }}>
            <TouchableOpacity 
              onPress={() => handleRetry(item.id)}
              style={{ flexDirection: 'row', alignItems: 'center', backgroundColor: isDark ? '#334155' : '#fef2f2', paddingHorizontal: 12, paddingVertical: 4, borderRadius: 12, gap: 4 }}
            >
              <Ionicons name="refresh" size={12} color={Colors.danger} />
              <Text style={{ fontSize: 11, color: Colors.danger }}>发送失败，点击重试</Text>
            </TouchableOpacity>
          </View>
        )}
      </View>
    );
  };

  // [FIX2 抖动] 稳定 key：优先真实 id；临时 msg_<ts> 在被服务端 id 替换前，用 role+时间桶+内容指纹兜底，
  // 保证“同一条消息”在后台轮询合并/重排前后 key 不变，FlatList 不会 remount 行而跳位。
  const stableMsgKey = (m: any, index: number): string => {
    if (m && m.id && !/^msg_\d+$/.test(String(m.id))) return String(m.id);
    if (m) {
      const bucket = Math.floor(Number(m.created_at) / (m.role === 'user' ? 5000 : 3000));
      const sig = (m.role || '') + '|' + bucket + '|' + String(m.content || '').trim().slice(0, 24);
      return 'k_' + sig;
    }
    return 'idx_' + index;
  };

  const renderFooter = () => {
    if (!isStreaming) return null;

    // 实时任务状态卡片：思考理解 → 正在生成图片/视频/搜索… → 正在输入回复
    // 紧跟最后一条消息展示，随后端工具事件实时切换阶段 + 计时
    const sanitizedStreaming = /task_id|任务ID|进度[：:\s]*\d+%|视频已生成完成|视频正在生成中|正在尝试生成视频|视频生成服务暂时不可用|关于视频链接|替代方案|状态[：:]\s*(queued|processing)/i.test(streamingContent)
      ? sanitizeVideoContent(streamingContent)
      : streamingContent;

    return (
      <View>
        {streamingContent ? (
          <View style={{ paddingHorizontal: Spacing.md, paddingVertical: Spacing.sm }}>
            <MessageBubble
              message={{
                id: streamingMessageId || '',
                conversation_id: conversationId || id || '',
                role: 'assistant',
                type: 'text',
                content: sanitizedStreaming,
                content_type: 'markdown',
                created_at: String(Date.now()),
                updated_at: String(Date.now()),
              }}
              userName={userName}
              botName={botName}
              botAvatar={botAvatar}
              userAvatar={userAvatar}
              isDark={isDark}
            />
          </View>
        ) : null}
      </View>
    );
  };

  return (
    <View style={[styles.container, { backgroundColor: isDark ? '#0f172a' : '#fff', paddingTop: 0, paddingBottom: 0 }]}>


      {showSearch && (
        <View style={[styles.searchBar, { backgroundColor: isDark ? '#1e293b' : Colors.backgroundSecondary }]}>
          <Ionicons name="search-outline" size={16} color={Colors.textTertiary} style={{ marginRight: 6 }} />
          <TextInput
            style={styles.searchInput}
            placeholder="搜索消息..."
            placeholderTextColor={Colors.textTertiary}
            value={searchQuery}
            onChangeText={setSearchQuery}
            autoFocus
          />
          {searchQuery ? (
            <Text style={styles.searchCount}>
              {messages.filter(m => (m.content || '').toLowerCase().includes(searchQuery.toLowerCase())).length} 条结果
            </Text>
          ) : null}
        </View>
      )}
      {isOffline && (
        <View style={styles.offlineBar}>
          <Ionicons name="cloud-offline-outline" size={14} color="#fff" />
          <Text style={styles.offlineText}> 网络已断开，消息可能无法发送</Text>
        </View>
      )}
      {initError ? (
        <View style={[styles.errorBar, { backgroundColor: isDark ? '#1c1917' : '#fef2f2', borderTopColor: isDark ? '#7f1d1d' : '#fecaca' }]}>
          <Ionicons name="alert-circle" size={14} color={Colors.danger} />
          <Text style={styles.errorText}> {initError}</Text>
        </View>
      ) : null}

      {messages.length === 0 && !isStreaming ? (
        <View style={styles.emptyArea}>
          <EmptyState iconName="chatbubbles" title={`和 ${botName} 开始对话`} subtitle="输入消息开始聊天" />
        </View>
      ) : (
        // FIX 2026-09-17 滚动狂跳：向上分页是头部插入老消息。不做位置保持时 FlatList
        // 默认锚定顶部 index，可视内容被整体下推，回底过程中反复命中顶部、触发 loadMore
        // 后再跳，形成狂跳循环。maintainVisibleContentPosition 锚定首个可见行，头部插入时
        // 自动补偿偏移、视口不动；autoscrollToTopThreshold 为 null 禁止自动滚顶。
        // RN0.76 iOS/Android 原生支持，web 端自动忽略该属性。
        // onEndReached 是到底部(最新消息)才触发，方向相反会在流式时打乱页码，故禁用，
        // 三端统一靠 onScroll 检测滚动到顶部来加载老消息。
        <FlatList
          style={{ flex: 1 }}
          ref={flatListRef}
          data={visibleMessages}
          renderItem={renderItem}
          keyExtractor={stableMsgKey}
          contentContainerStyle={styles.listContent}
          ListFooterComponent={renderFooter}
          ListHeaderComponent={loadingMore ? (
            <View style={{ padding: 16, alignItems: 'center' }}>
              {<ActivityIndicator size="small" color={Colors.primary} />}
              <Text style={{ fontSize: 12, color: Colors.textTertiary, marginTop: 4 }}>加载中...</Text>
            </View>
          ) : !hasMore && messages.length > 0 ? (
            <View style={{ padding: 16, alignItems: 'center' }}>
              <Text style={{ fontSize: 12, color: Colors.textTertiary }}>没有更多消息了</Text>
            </View>
          ) : null}
          onEndReached={undefined}
          onEndReachedThreshold={0}
          showsVerticalScrollIndicator={false}
          inverted={false}
          {...(enableMvcp ? {
            maintainVisibleContentPosition: {
              minIndexForVisible: 0,
              autoscrollToTopThreshold: null,
            },
          } : {})}
          extraData={videoTasks}
          onScroll={handleScroll}
          onContentSizeChange={() => {
            // [v105] 流式打字内容长高时：跟随态下平滑贴底（节流+尾部补偿，不与滚动位打架）；
            // 用户上翻锁定期间完全不动。图片固定 220 高占位，历史图片加载也不会误触发跳动。
            if (isStreaming) {
              requestFollowStream();
            }
          }}
          onLayout={() => {
            // [FIX2 抖动] 仅首屏还没定位过时滚一次底；之后键盘弹起/旋转/布局变化一律不碰滚动位置。
            if (!didInitialScrollRef.current) {
              didInitialScrollRef.current = true;
              requestFollow({ force: true });
              setTimeout(() => setEnableMvcp(true), 160);
            }
          }}
          onScrollBeginDrag={() => {
            // 用户手指开始拖拽：立即锁定跟随，且粘滞保持
            markUserScrolling();
          }}
          onScrollEndDrag={() => {
            // 松手后给惯性留短缓冲；缓冲结束时若仍在上方则继续锁定（位置判定，不自动解锁）
            markUserScrolling(250);
          }}
          onMomentumScrollBegin={() => {
            markUserScrolling();
          }}
          onMomentumScrollEnd={() => {
            // 惯性结束：由 handleScroll 据当前位置决定；不在底部就继续锁
            markUserScrolling(120);
          }}
          {...(Platform.OS === 'web' ? {
            onWheel: (e: any) => {
              // Web 端滚轮上滚（deltaY<0）即视为用户主动上翻：粘滞锁定，直到他自己滚回底部
              if (e && e.nativeEvent && typeof e.nativeEvent.deltaY === 'number' && e.nativeEvent.deltaY < -1) {
                markUserScrolling();
              }
            },
          } : {})}
          scrollEventThrottle={Platform.OS === 'web' ? 16 : 100}
        />
      )}

      {error ? (
        <View style={[styles.errorBar, { backgroundColor: isDark ? '#1c1917' : '#fef2f2', borderTopColor: isDark ? '#7f1d1d' : '#fecaca' }]}>
          <Ionicons name="alert-circle" size={14} color={Colors.danger} />
          <Text style={styles.errorText}> {error}</Text>
        </View>
      ) : null}

      {/* Scroll to bottom button */}
      {showScrollBtn && (
        <TouchableOpacity
          onPress={scrollToBottom}
          style={{
            position: 'absolute',
            right: 16,
            bottom: 80 + keyboardHeight,
            width: 40,
            height: 40,
            borderRadius: 20,
            backgroundColor: 'rgba(0,0,0,0.3)',
            justifyContent: 'center',
            alignItems: 'center',
            zIndex: 10,
            elevation: 5,
            shadowColor: '#000',
            shadowOffset: { width: 0, height: 2 },
            shadowOpacity: 0.2,
            shadowRadius: 4,
          }}
          activeOpacity={0.7}
        >
          <Ionicons name="chevron-down" size={22} color="#fff" />
        </TouchableOpacity>
      )}

      {/* Dynamic typing indicator + input with keyboard avoidance */}
      <View style={{ marginBottom: keyboardHeight + (Platform.OS === 'ios' ? insets.bottom : 0) }}>
        {(conversationId || id) ? (
          <DagProgressCard conversationId={(conversationId || id || '') as string} isDark={isDark} />
        ) : null}
        {isStreaming && (!streamingContent || toolCalls.some((tc) => !tc.result)) ? (
          <TaskStatusCard
            status={activityStatus}
            tools={toolCalls.map((tc) => ({
              id: tc.id,
              name: tc.name,
              label: getToolMeta(tc.name).label,
              done: !!tc.result,
            }))}
            botName={botName}
            isDark={isDark}
          />
        ) : null}
        <ChatInput
        onSend={handleSend}
        onStop={handleStop}
        isStreaming={isStreaming}
        placeholder={`给 ${botName} 发消息...`}
        conversationId={conversationId || id}
        patToken={patToken || undefined}
        quotedMessage={quotedMessage}
        onClearQuote={() => setQuotedMessage(null)}
        initialText={prompt as string | undefined}
      />

      </View>

      {/* Bot selector modal */}
      <Modal
        visible={showBotSelector}
        transparent
        animationType="fade"
        onRequestClose={() => setShowBotSelector(false)}
      >
        <TouchableOpacity
          style={{ flex: 1, justifyContent: 'center', alignItems: 'center', backgroundColor: 'rgba(0,0,0,0.4)' }}
          activeOpacity={1}
          onPress={() => setShowBotSelector(false)}
        >
          <View style={{ backgroundColor: isDark ? '#1e293b' : '#fff', borderRadius: 16, padding: 20, width: 300, maxHeight: 400 }}>
            <Text style={{ fontSize: 17, fontWeight: '700', color: isDark ? '#f1f5f9' : '#0f172a', textAlign: 'center', marginBottom: 16 }}>选择 AI 模型</Text>
            {availableBots.length === 0 ? (
              <ActivityIndicator size="small" color={Colors.primary} style={{ marginVertical: 20 }} />
            ) : (
              <ScrollView style={{ maxHeight: 300 }}>
                {availableBots.map((bot) => (
                  <TouchableOpacity
                    key={bot.id}
                    style={{
                      flexDirection: 'row', alignItems: 'center',
                      paddingVertical: 12, paddingHorizontal: 12,
                      borderRadius: 10,
                      backgroundColor: bot.id === currentBotId ? (isDark ? '#2d1b69' : '#f3eeff') : 'transparent',
                      marginBottom: 4,
                    }}
                    onPress={() => handleBotSwitch(bot.id, bot.name)}
                    activeOpacity={0.7}
                  >
                    <View style={{ width: 36, height: 36, borderRadius: 18, backgroundColor: Colors.primary, justifyContent: 'center', alignItems: 'center', marginRight: 12 }}>
                      <Ionicons name="sparkles" size={16} color="#fff" />
                    </View>
                    <View style={{ flex: 1 }}>
                      <Text style={{ fontSize: 15, fontWeight: '600', color: isDark ? '#f1f5f9' : '#0f172a' }}>{bot.name}</Text>
                      <Text style={{ fontSize: 11, color: isDark ? '#94a3b8' : '#64748b', marginTop: 2 }}>{bot.id === currentBotId ? '当前使用' : '点击切换'}</Text>
                    </View>
                    {bot.id === currentBotId && <Ionicons name="checkmark-circle" size={18} color={Colors.primary} />}
                  </TouchableOpacity>
                ))}
              </ScrollView>
            )}
          </View>
        </TouchableOpacity>
      </Modal>

      {/* Long press action menu */}
      <Modal
        visible={longPressMenu.visible}
        transparent
        animationType="fade"
        onRequestClose={closeMenu}
      >
        <TouchableOpacity
          style={styles.menuOverlay}
          activeOpacity={1}
          onPress={closeMenu}
        >
          <View style={[styles.actionMenu, { backgroundColor: isDark ? '#1e293b' : '#fff' }]}>
            <TouchableOpacity style={styles.menuItem} onPress={handleQuote}>
              <Ionicons name="return-down-back-outline" size={18} color={Colors.primary} />
              <Text style={styles.menuItemText}>引用</Text>
            </TouchableOpacity>
            <View style={styles.menuDivider} />
            <TouchableOpacity style={styles.menuItem} onPress={handleCopy}>
              <Ionicons name="copy-outline" size={18} color={Colors.text} />
              <Text style={styles.menuItemText}>复制</Text>
            </TouchableOpacity>

          </View>
        </TouchableOpacity>
      </Modal>

    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: '#fff', paddingTop: Platform.OS === 'web' ? 0 : 0, paddingBottom: Platform.OS === 'web' ? 0 : Spacing.sm },
  loading: { flex: 1, justifyContent: 'center', alignItems: 'center' },
  emptyArea: { flex: 1, justifyContent: 'center' },
  listContent: { paddingVertical: Spacing.md, paddingBottom: 120 },
  errorBar: {
    flexDirection: 'row', alignItems: 'center',
    backgroundColor: '#fef2f2',
    paddingHorizontal: Spacing.md, paddingVertical: Spacing.xs,
    borderTopWidth: 0.5, borderTopColor: '#fecaca',
  },
  errorText: { fontSize: 12, color: Colors.danger, marginLeft: 4 },
  // Menu
  menuOverlay: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    backgroundColor: 'rgba(0,0,0,0.3)',
  },
  actionMenu: {
    backgroundColor: '#fff',
    borderRadius: 14,
    paddingVertical: 4,
    minWidth: 160,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 4 },
    shadowOpacity: 0.15,
    shadowRadius: 12,
    elevation: 8,
  },
  menuItem: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: 20,
    paddingVertical: 14,
    gap: 12,
  },
  menuItemText: {
    fontSize: 16,
    color: Colors.text,
  },


  searchBar: {
    flexDirection: 'row', alignItems: 'center',
    backgroundColor: Colors.backgroundSecondary,
    marginHorizontal: Spacing.md, marginVertical: Spacing.xs,
    paddingHorizontal: Spacing.md, height: 36,
    borderRadius: BorderRadius.full,
  },
  searchInput: { flex: 1, fontSize: FontSize.sm, color: Colors.text, paddingVertical: 0 },
  searchCount: { fontSize: FontSize.xs, color: Colors.textTertiary, marginLeft: 6 },
  offlineBar: {
    flexDirection: 'row', alignItems: 'center', justifyContent: 'center',
    backgroundColor: '#ef4444', paddingVertical: 6, paddingHorizontal: Spacing.md,
  },
  offlineText: { color: '#fff', fontSize: 12 },
  menuDivider: {
    height: 0.5,
    backgroundColor: '#e5e5e5',
    marginHorizontal: 16,
  },
  // Generation placeholder row
  genPlaceholderRow: {
    flexDirection: 'row',
    alignItems: 'flex-start',
  },
  genAvatar: {
    width: 30,
    height: 30,
    borderRadius: 15,
    justifyContent: 'center',
    alignItems: 'center',
    marginRight: 8,
  },
  // Thinking indicator
  thinkingRow: {
    flexDirection: 'row',
    alignItems: 'center',
  },
  thinkingBubble: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: Colors.backgroundSecondary,
    paddingHorizontal: 14,
    paddingVertical: 10,
    borderRadius: BorderRadius.lg,
    borderBottomLeftRadius: BorderRadius.xs,
    gap: 8,
  },
  thinkingText: {
    fontSize: FontSize.sm,
    color: Colors.textTertiary,
  },
});
// QUEUE_FIX_20260811


export default function ChatDetailScreen() {
  return (
    <ChatErrorBoundary>
      <ChatDetailScreenInner />
    </ChatErrorBoundary>
  );
}

