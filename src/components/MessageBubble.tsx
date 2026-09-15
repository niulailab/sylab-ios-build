import React, { useState, useRef } from 'react';
import { View, Text, StyleSheet, Image, TouchableOpacity, Platform, ActivityIndicator } from 'react-native';
import { Audio } from 'expo-av';

import { Colors, Spacing, BorderRadius, FontSize } from '../constants/theme';
import { MarkdownRenderer } from './MarkdownRenderer';
import { ZoomableImage } from './ImageLightbox';
import { Ionicons } from '@expo/vector-icons';
import type { ChatMessage, ToolCall } from '../types/api';


const API_BASE = 'https://s.symsgf.xyz';

// Convert HTTP server URLs to HTTPS tunnel for iOS ATS
function normalizeImageUrl(url: string): string {
  if (!url) return url;
  // 后端 MinIO 内网地址（头像、生成图片等）→ 公网代理路径，去掉签名参数
  const minioM = url.match(/https?:\/\/[^/]*minio[^/]*\/(opencoze\/.*)$/i);
  if (minioM) {
    return `https://s.symsgf.xyz/minio-files/${minioM[1]}`.split('?')[0];
  }
  return url
    .replace(/http:\/\/36\.137\.84\.216:9091/g, "https://s.symsgf.xyz")
    .replace(/http:\/\/127\.0\.0\.1:9091/g, "https://s.symsgf.xyz")
    .replace(/http:\/\/localhost:9091/g, "https://s.symsgf.xyz");
}

interface MessageBubbleProps {
  message: ChatMessage;
  isDark?: boolean;
  userName?: string;
  botName?: string;
  botAvatar?: string;
  userAvatar?: string;
  onLongPress?: (message: ChatMessage) => void;
  replyToMessage?: { role: string; content: string } | null;
  cost?: number;
}

const ToolCallCard: React.FC<{ toolCall: ToolCall; isDark?: boolean }> = ({ toolCall, isDark }) => {
  const name = toolCall.function?.name || toolCall.name || 'unknown';
  const rawArgs = toolCall.function?.arguments || toolCall.arguments || '{}';
  let argsDisplay = rawArgs;
  try {
    argsDisplay = JSON.stringify(JSON.parse(rawArgs), null, 2);
  } catch {}
  return (
    <View style={[styles.toolCard, { backgroundColor: isDark ? '#1e293b' : Colors.primaryLight, borderColor: isDark ? '#334155' : '#d0d0d0' }]}>
      <View style={styles.toolHeader}>
        <Ionicons name="build-outline" size={14} color={Colors.textSecondary} />
        <Text style={[styles.toolName, { color: Colors.textSecondary }]}>{name}</Text>
      </View>
      <Text style={[styles.toolArgs, { color: isDark ? '#94a3b8' : Colors.textSecondary }]} numberOfLines={3}>{argsDisplay}</Text>
    </View>
  );
};

const stripMd = (text: string): string => {
  if (!text) return "";
  return text
    .replace(/<img\s[^>]*alt="([^"]*)"[^>]*>/gi, (_, alt) => alt ? `[图片]` : "[图片]")
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

const QuotePreview: React.FC<{ replyTo: { role: string; content: string }; isDark?: boolean }> = ({ replyTo, isDark }) => {
  const label = replyTo.role === 'user' ? '我' : 'AI';
  const preview = stripMd(replyTo.content).substring(0, 60);
  if (!preview) return null;
  return (
    <View style={[quoteStyles.container, { backgroundColor: isDark ? '#1e293b' : '#f8f8f8', borderLeftColor: '#d0d0d0' }]}>
      <Text style={[quoteStyles.label, { color: Colors.textTertiary }]}>{label}</Text>
      <Text style={[quoteStyles.text, { color: isDark ? '#94a3b8' : Colors.textSecondary }]} numberOfLines={2}>{preview}</Text>
    </View>
  );
};

const quoteStyles = StyleSheet.create({
  container: { borderLeftWidth: 2, paddingLeft: 8, paddingRight: 8, paddingVertical: 4, marginBottom: 6, borderRadius: 4, maxWidth: '100%' },
  label: { fontSize: 11, fontWeight: '500', marginBottom: 1 },
  text: { fontSize: 12, lineHeight: 16 },
});

const formatTime = (createdAt: string | number): string => {
  const ts = typeof createdAt === 'string' ? Number(createdAt) : createdAt;
  const ms = ts < 1e12 ? ts * 1000 : ts;
  const d = new Date(ms);
  const h = d.getHours().toString().padStart(2, '0');
  const m = d.getMinutes().toString().padStart(2, '0');
  return `${h}:${m}`;
};

// Avatar component - shows image or fallback colored circle
const AvatarCircle: React.FC<{ url?: string; isUser?: boolean }> = ({ url, isUser }) => {
  const [imgError, setImgError] = React.useState(false);
  const fixed = url ? normalizeImageUrl(url) : '';
  const validUrl = !!fixed && fixed.trim().length > 0 && !imgError;
  if (validUrl) {
    return (
      <Image
        source={{ uri: fixed }}
        style={headerStyles.avatar}
        onError={() => setImgError(true)}
      />
    );
  }
  const bgColor = isUser ? '#5b9bd5' : '#757575';
  return (
    <View style={[headerStyles.avatar, { backgroundColor: bgColor }]}>
      <Ionicons name="person" size={14} color="#fff" />
    </View>
  );
};

const MessageHeader: React.FC<{ role: string; createdAt: string | number; isDark?: boolean; userName?: string; botName?: string; isUser?: boolean; botAvatar?: string; userAvatar?: string }> = ({ role, createdAt, isDark, userName, botName, isUser: isUserProp, botAvatar, userAvatar }) => {
  const isUser = isUserProp !== undefined ? isUserProp : role === 'user';
  const rawName = isUser ? (userName || '用户') : (botName || 'sylab AI');
  const name = /^\d+$/.test(rawName.trim()) ? '用户' : rawName;
  const time = formatTime(createdAt);

  if (isUser) {
    // User: right-aligned. Order: name | time | avatar
    return (
      <View style={[headerStyles.row, { justifyContent: 'flex-end' }]}>
        <Text style={[headerStyles.name, { color: isDark ? '#e2e8f0' : Colors.text }]}>{name}</Text>
        <Text style={[headerStyles.time, { color: Colors.textTertiary }]}>{time}</Text>
        <AvatarCircle url={userAvatar} isUser={true} />
      </View>
    );
  }
  // AI: left-aligned. Order: avatar | name | time
  return (
    <View style={headerStyles.row}>
      <AvatarCircle url={botAvatar} isUser={false} />
      <Text style={[headerStyles.name, { color: isDark ? '#e2e8f0' : Colors.text }]}>{name}</Text>
      <Text style={[headerStyles.time, { color: Colors.textTertiary }]}>{time}</Text>
    </View>
  );
};

const headerStyles = StyleSheet.create({
  row: { flexDirection: 'row', alignItems: 'center', marginBottom: 4, gap: 6 },
  avatar: { width: 28, height: 28, borderRadius: 14, justifyContent: 'center', alignItems: 'center', flexShrink: 0 },
  name: { fontSize: 14, fontWeight: '600' },
  time: { fontSize: 12, fontWeight: '400' },
});

const webSelectionCSS = Platform.OS === 'web' ? `
  .bubble-text * { user-select: text !important; -webkit-user-select: text !important; }
  .bubble-text { user-select: text !important; -webkit-user-select: text !important; cursor: text; }
` : '';

export const MessageBubble = React.memo<MessageBubbleProps>(({ message, isDark, userName, botName, botAvatar, userAvatar, onLongPress, replyToMessage, cost }) => {
  const isUser = message.role === 'user';
  const isSystem = message.role === 'system';
  const isTool = message.role === 'tool';
  const [isPlaying, setIsPlaying] = useState(false);
  const [isTtsLoading, setIsTtsLoading] = useState(false);
  const soundRef = useRef<Audio.Sound | null>(null);

  const handleTtsPlay = async () => {
    if (isPlaying && soundRef.current) {
      await soundRef.current.stopAsync();
      await soundRef.current.unloadAsync();
      soundRef.current = null;
      setIsPlaying(false);
      return;
    }
    try {
      setIsTtsLoading(true);
      const plainText = stripMd(message.content);
      const resp = await fetch(API_BASE + '/api/tts/synthesize', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        credentials: 'include',
        body: JSON.stringify({ text: plainText, voice: 'tongtong' }),
      });
      const data = await resp.json();
      setIsTtsLoading(false);
      if (data.code === 0 && data.data && data.data.audio) {
        // Convert hex to base64 for playback
        const hex = data.data.audio;
        const bytes = [];
        for (let i = 0; i < hex.length; i += 2) {
          bytes.push(parseInt(hex.substr(i, 2), 16));
        }
        const binary = bytes.reduce((s, b) => s + String.fromCharCode(b), '');
        const b64 = btoa(binary);
        const sound = new Audio.Sound();
        await sound.loadAsync({
          uri: 'data:audio/wav;base64,' + b64,
        });
        soundRef.current = sound;
        setIsPlaying(true);
        sound.setOnPlaybackStatusUpdate((status: any) => {
          if (status.isLoaded && status.didJustFinish) {
            setIsPlaying(false);
            soundRef.current = null;
          }
        });
        await sound.playAsync();
      }
    } catch (e) {
      console.error('[MessageBubble] TTS error:', e);
      setIsTtsLoading(false);
      setIsPlaying(false);
    }
  };

  if (isSystem) {
    return (
      <View style={styles.systemContainer}>
        <Text style={[styles.systemText, { color: isDark ? '#64748b' : Colors.textTertiary }]}>{message.content}</Text>
      </View>
    );
  }

  if (isTool) {
    return (
      <View style={styles.toolResultContainer}>
        <View style={styles.toolResultBadge}>
          <Ionicons name="checkmark-circle" size={14} color={Colors.success} />
          <Text style={[styles.toolResultLabel, { color: Colors.success }]}> 工具返回</Text>
        </View>
        <Text style={[styles.toolResultText, { color: isDark ? '#e2e8f0' : Colors.text }]} numberOfLines={5}>{message.content}</Text>
      </View>
    );
  }

  const bubbleBg = isUser ? Colors.bubbleUser : (isDark ? Colors.bubbleAssistantDark : Colors.bubbleAssistant);
  const textColor = isDark ? Colors.textInverse : Colors.text;

  const bubbleContent = (
    <View style={{ alignItems: isUser ? 'flex-end' : 'flex-start', width: '100%', minWidth: 0, flexShrink: 1 }}>
      {replyToMessage && !isUser && (
        <View style={{ width: '100%', maxWidth: '100%', minWidth: 0, flexShrink: 1, paddingHorizontal: Spacing.md }}>
          <QuotePreview replyTo={replyToMessage} isDark={isDark} />
        </View>
      )}
      {onLongPress ? (
        <TouchableOpacity
          activeOpacity={0.7}
          onLongPress={() => onLongPress(message)}
          delayLongPress={400}
          style={{ alignSelf: isUser ? 'flex-end' : 'flex-start' }}
        >
          <MessageHeader role={message.role} createdAt={message.created_at} isDark={isDark} userName={userName} botName={botName} isUser={isUser} botAvatar={botAvatar} userAvatar={userAvatar} />
        </TouchableOpacity>
      ) : (
        <MessageHeader role={message.role} createdAt={message.created_at} isDark={isDark} userName={userName} botName={botName} isUser={isUser} botAvatar={botAvatar} userAvatar={userAvatar} />
      )}
      <View style={[
        styles.bubble,
        isUser ? styles.userBubble : styles.assistantBubble,
        { backgroundColor: bubbleBg },
      ]}>
        {message.content_type === 'image_url' && message.content ? (() => {
          const _c = message.content || '';
          const _imgMatch = _c.match(/^\[IMG:([^\]]+)\](.*)$/s);
          const _imgUrl = _imgMatch ? _imgMatch[1] : _c;
          const _imgText = _imgMatch ? _imgMatch[2].trim() : '';
          return (
            <View>
              <Image source={{ uri: normalizeImageUrl(_imgUrl) }} style={styles.messageImage} />
              {_imgText ? <Text style={[styles.userText, { color: textColor, marginTop: 6 }]} selectable>{_imgText}</Text> : null}
            </View>
          );
        })() : isUser ? (
          <Text style={[styles.userText, { color: textColor }]} selectable>{message.content}</Text>
        ) : (
          <MarkdownRenderer content={message.content} isDark={isDark} />
        )}
        {!isUser && cost && cost > 0 && (
          <View style={styles.costContainer}>
            <Ionicons name="diamond" size={10} color={Colors.primary} />
            <Text style={styles.costText}>{Number.isInteger(cost) ? cost : cost.toFixed(1)}</Text>
          </View>
        )}
        {!isUser && !isSystem && !isTool && message.content_type !== 'image_url' && (
          <TouchableOpacity style={styles.ttsButton} onPress={handleTtsPlay} activeOpacity={0.6}>
            {isTtsLoading ? (
              <ActivityIndicator size="small" color={Colors.primary} />
            ) : (
              <Ionicons name={isPlaying ? "pause-circle" : "play-circle"} size={22} color={Colors.primary} />
            )}
            <Text style={styles.ttsLabel}>{isTtsLoading ? '\u8f6c\u6362\u4e2d...' : isPlaying ? '\u6682\u505c' : '\u6717\u8bfb'}</Text>
          </TouchableOpacity>
        )}
      </View>
    </View>
  );

  // 注意：正文气泡不能被带 onLongPress 的 Touchable 包裹，
  // 否则长按手势与 selectable Text 冲突，只能整体复制、无法局部选词。
  // 消息操作菜单改由头部（头像/名字/时间行）长按触发。
  return (
    <View style={[styles.row, { justifyContent: isUser ? 'flex-end' : 'flex-start' }]}>
      <View style={[styles.bubbleWrapper, { maxWidth: isUser ? '85%' : '96%', alignItems: isUser ? 'flex-end' : 'flex-start' }]}>
        {bubbleContent}
      </View>
    </View>
  );
});

const styles = StyleSheet.create({
  row: { flexDirection: 'row', marginVertical: 6, paddingHorizontal: 16 },
  avatar: { width: 30, height: 30, borderRadius: 15, justifyContent: 'center', alignItems: 'center', marginHorizontal: 6, flexShrink: 0 },
  avatarText: { color: '#fff', fontSize: FontSize.xs, fontWeight: '600' },
  bubble: { flexShrink: 1, flexGrow: 0, width: '100%', minWidth: 220, maxWidth: '96%', paddingHorizontal: 12, paddingVertical: 8, borderRadius: BorderRadius.md },
  bubbleWrapper: { flexShrink: 1, flexGrow: 0, minWidth: 0, alignSelf: 'flex-start' },
  userBubble: { borderBottomRightRadius: BorderRadius.xs },
  userText: { fontSize: FontSize.md, lineHeight: FontSize.md * 1.5 },
  assistantBubble: { borderBottomLeftRadius: BorderRadius.xs },
  messageImage: { width: 200, height: 200, borderRadius: BorderRadius.md, marginTop: Spacing.xs },
  systemContainer: { alignItems: 'center', marginVertical: Spacing.sm },
  systemText: { fontSize: FontSize.xs, textAlign: 'center' },
  toolCard: { borderRadius: BorderRadius.sm, padding: Spacing.sm, marginTop: Spacing.xs, borderWidth: 1 },
  toolHeader: { flexDirection: 'row', alignItems: 'center', marginBottom: 4, gap: 4 },
  toolName: { fontSize: FontSize.sm, fontWeight: '500' },
  toolArgs: { fontSize: FontSize.xs, fontFamily: 'monospace' },
  toolResultContainer: { marginVertical: Spacing.xs, paddingHorizontal: Spacing.md },
  toolResultBadge: { flexDirection: 'row', alignItems: 'center', marginBottom: 4 },
  toolResultLabel: { fontSize: FontSize.xs, fontWeight: '500' },
  toolResultText: { fontSize: FontSize.sm },
  costContainer: { flexDirection: 'row', alignItems: 'center', paddingTop: 4, alignSelf: 'flex-end', gap: 2, opacity: 0.7 },
  costText: { fontSize: 11, color: Colors.textTertiary },
  ttsButton: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 4,
    marginTop: 6,
    paddingHorizontal: 8,
    paddingVertical: 4,
    borderRadius: 12,
    alignSelf: 'flex-start',
  },
  ttsLabel: {
    fontSize: 12,
    color: Colors.primary,
    fontWeight: '500',
  },
});
