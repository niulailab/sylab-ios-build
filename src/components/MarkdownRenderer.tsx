import { toRuntimeUrl } from '../config/runtime';
import React from 'react';
import { View, Text, StyleSheet, ScrollView, Image, TouchableOpacity, Linking, Platform, Dimensions, Modal, ActivityIndicator } from 'react-native';
// expo-video dynamically imported to prevent native crash on iOS 26
import { Colors, Spacing, BorderRadius, FontSize } from '../constants/theme';
import { ZoomableImage } from './ImageLightbox';
import * as Clipboard from 'expo-clipboard';
import { downloadAndShare, openExternally, previewFile, fetchFileSize, formatFileSize } from '../utils/fileOpen';

// Fixed pixel width for horizontal table scroll (avoids flexbox circular dependency)
const TABLE_SCROLL_W = Math.max(200, (Dimensions.get('window').width - 32) * 0.96 - 24);

// Convert HTTP server URLs to HTTPS tunnel URLs to bypass iOS ATS
function normalizeImageUrl(url: string): string {
  if (!url) return url;
  return toRuntimeUrl(url);
}

interface MarkdownRendererProps {
  content: string;
  isDark?: boolean;
}

const webWrapCSS = Platform.OS === 'web' ? `
  .md-bubble p, .md-bubble li, .md-bubble td, .md-bubble th, .md-bubble h1, .md-bubble h2, .md-bubble h3, .md-bubble blockquote { word-wrap: break-word; overflow-wrap: break-word; white-space: pre-wrap; }
  .md-bubble p a, .md-bubble p code { word-break: break-all; }
  .md-table-scroll { max-width: 100%; overflow-x: auto; -webkit-overflow-scrolling: touch; scroll-behavior: smooth; }
  .md-table-scroll::-webkit-scrollbar { height: 4px; }
  .md-table-scroll::-webkit-scrollbar-thumb { background: #cbd5e1; border-radius: 2px; }
` : '';

// Error boundary for video player to prevent native crashes
class VideoErrorBoundary extends React.Component<
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
        <View style={{ marginVertical: 8, padding: 16, backgroundColor: '#f3f4f6', borderRadius: 12, alignItems: 'center' }}>
          <Text style={{ color: '#6b7280', fontSize: 13 }}>视频加载失败</Text>
        </View>
      );
    }
    return this.props.children;
  }
}

// 视频 App 内下载按钮：下载到缓存后弹系统分享面板（可"存储到视频/文件"），不跳浏览器
function VideoDownloadButton({ src }: { src: string }) {
  const [downloading, setDownloading] = React.useState(false);
  const [progress, setProgress] = React.useState(0);
  if (Platform.OS === 'web') return null;
  const onPress = async () => {
    if (downloading) return;
    setDownloading(true);
    setProgress(0);
    try {
      await downloadAndShare(src, (r) => setProgress(r));
    } finally {
      setTimeout(() => { setDownloading(false); setProgress(0); }, 400);
    }
  };
  return (
    <TouchableOpacity onPress={onPress} activeOpacity={0.7} disabled={downloading}
      style={{ flexDirection: 'row', alignItems: 'center', justifyContent: 'center',
        paddingVertical: 9, backgroundColor: '#1f2937' }}>
      {downloading ? (
        <>
          <ActivityIndicator size="small" color="#fff" style={{ marginRight: 6 }} />
          <Text style={{ color: '#fff', fontSize: 12 }}>
            {progress >= 1 ? '正在打开…' : `下载中 ${Math.round(progress * 100)}%`}
          </Text>
        </>
      ) : (
        <>
          <Text style={{ color: '#fff', fontSize: 15, marginRight: 5 }}>⬇</Text>
          <Text style={{ color: '#fff', fontSize: 13, fontWeight: '600' }}>下载视频</Text>
        </>
      )}
    </TouchableOpacity>
  );
}

// 表格专用错误边界：单个表格渲染异常时降级为纯文本，绝不让整张表/整条消息消失
class TableErrorBoundary extends React.Component<
  { fallback: React.ReactNode; children: React.ReactNode },
  { hasError: boolean }
> {
  constructor(props: { fallback: React.ReactNode; children: React.ReactNode }) {
    super(props);
    this.state = { hasError: false };
  }
  static getDerivedStateFromError() {
    return { hasError: true };
  }
  componentDidCatch(err: any) {
    console.warn('[MarkdownRenderer] table render error:', err?.message || err);
  }
  render() {
    if (this.state.hasError) return this.props.fallback;
    return this.props.children;
  }
}

// Inline video player component - dynamic import to prevent native crash on page load
function VideoPlayerInline({ src, videoKey }: { src: string; videoKey: string }) {
  const [videoModule, setVideoModule] = React.useState<{ useVideoPlayer: any; VideoView: any } | null>(null);
  const [loadError, setLoadError] = React.useState(false);

  React.useEffect(() => {
    if (!src || Platform.OS === 'web') return;
    let mounted = true;
    import('expo-video').then(mod => {
      if (mounted) setVideoModule({ useVideoPlayer: mod.useVideoPlayer, VideoView: mod.VideoView });
    }).catch(() => {
      if (mounted) setLoadError(true);
    });
    return () => { mounted = false; };
  }, [src]);

  if (Platform.OS === 'web') {
    return (
      <View style={{ marginVertical: 8, borderRadius: 12, overflow: 'hidden' }}>
        <video src={src} controls style={{ width: '100%', maxWidth: 480, borderRadius: 12, backgroundColor: '#000' }} />
      </View>
    );
  }
  if (loadError) {
    return (
      <View style={{ marginVertical: 8, padding: 20, backgroundColor: '#f3f4f6', borderRadius: 12, alignItems: 'center' }}>
        <Text style={{ color: '#6b7280', fontSize: 13 }}>视频播放不可用</Text>
      </View>
    );
  }
  if (!videoModule) {
    return (
      <View style={{ marginVertical: 8, height: 200, backgroundColor: '#000', borderRadius: 12,
        alignItems: 'center', justifyContent: 'center' }}>
        <ActivityIndicator size="small" color="#9ca3af" />
        <Text style={{ color: '#9ca3af', fontSize: 13, marginTop: 8 }}>加载视频...</Text>
      </View>
    );
  }
  return (
    <VideoErrorBoundary>
      <View style={{ marginVertical: 8, borderRadius: 12, overflow: 'hidden', backgroundColor: '#000' }}>
        <NativeVideoInline src={src} useVideoPlayer={videoModule.useVideoPlayer} VideoView={videoModule.VideoView} />
        <VideoDownloadButton src={src} />
      </View>
    </VideoErrorBoundary>
  );
}

function NativeVideoInline({ src, useVideoPlayer, VideoView }: { src: string; useVideoPlayer: any; VideoView: any }) {
  const player = useVideoPlayer(src, (p: any) => { p.loop = false; });
  return (
    <View style={{ backgroundColor: '#000' }}>
      <VideoView player={player} style={{ width: '100%', height: 200 }} contentFit="contain" allowsFullscreen allowsPictureInPicture />
    </View>
  );
}

// ===== Module-level helper functions (moved outside component) =====

function renderImgTag(tag: string, key: string, isDark?: boolean): React.ReactNode {
  const srcMatch = tag.match(/src=["']([^"']+)["']/);
  if (!srcMatch) return null;
  const src = srcMatch[1];
  const altMatch = tag.match(/alt=["']([^"']+)["']/);
  const alt = altMatch ? altMatch[1] : '';
  return (
    <View key={key} style={styles.imgContainer}>
      <ZoomableImage uri={normalizeImageUrl(src)}>
        <Image source={{ uri: normalizeImageUrl(src) }} style={styles.img} resizeMode="cover" />
      </ZoomableImage>
      {alt ? <Text style={{ fontSize: 11, color: '#94a3b8', marginTop: 4, textAlign: 'center' }}>{alt}</Text> : null}
    </View>
  );
}

function renderVideoTag(tag: string, key: string): React.ReactNode {
  let src = '';
  const srcMatch = tag.match(/<video[^>]*src=["']([^"']+)["']/);
  if (srcMatch) {
    src = srcMatch[1];
  } else {
    const sourceMatch = tag.match(/<source[^>]*src=["']([^"']+)["']/);
    if (sourceMatch) src = sourceMatch[1];
  }
  if (!src) return null;
  // [FIX] Use inline video player instead of openExternally
  return <VideoPlayerInline key={key} src={src} videoKey={key} />;
}

const OFFICE_EXT_MAP: { [k: string]: { icon: string; color: string; label: string } } = {
  '.pptx': { icon: '📊', color: '#e8643a', label: 'PPT' },
  '.ppt':  { icon: '📊', color: '#e8643a', label: 'PPT' },
  '.docx': { icon: '📝', color: '#2b6fd6', label: 'Word' },
  '.doc':  { icon: '📝', color: '#2b6fd6', label: 'Word' },
  '.xlsx': { icon: '📈', color: '#21a366', label: 'Excel' },
  '.xls':  { icon: '📈', color: '#21a366', label: 'Excel' },
  '.csv':  { icon: '📈', color: '#21a366', label: 'CSV' },
  '.pdf':  { icon: '📕', color: '#d63b3b', label: 'PDF' },
  '.zip':  { icon: '🗜️', color: '#8a63d2', label: 'ZIP' },
  '.txt':  { icon: '📄', color: '#64748b', label: 'TXT' },
  '.md':   { icon: '📄', color: '#64748b', label: 'MD' },
};

function pickFileInfo(url: string): { ext: string; name: string; info: any } | null {
  const m = url.match(/\.(pptx|ppt|docx|doc|xlsx|xls|csv|pdf|zip|txt|md)(\?|$)/i);
  if (!m) return null;
  const ext = '.' + m[1].toLowerCase();
  const info = OFFICE_EXT_MAP[ext];
  if (!info) return null;
  // 文件名取 URL 末段并解码
  let name = url.split('?')[0].split('/').pop() || ('file' + ext);
  try { name = decodeURIComponent(name); } catch {}
  name = name.replace(/^upload_/, '');
  return { ext, name, info };
}



// ===== Syntax Highlight Helper =====
function highlightCode(code: string, lang: string, isDark: boolean, keyPrefix: string): React.ReactNode[] {
  const defaultColor = isDark ? '#dcdcdc' : '#333';
  const keywordColor = '#c678dd';
  const stringColor = '#98c379';
  const commentColor = '#5c6370';
  const numberColor = '#d19a66';
  const funcColor = '#61afef';

  const jsKeywords = 'const|let|var|function|return|if|else|for|while|do|switch|case|break|continue|new|this|class|extends|import|export|from|default|try|catch|finally|throw|async|await|yield|typeof|instanceof|in|of|null|undefined|true|false|void|delete';
  const pyKeywords = 'def|return|if|elif|else|for|while|import|from|class|try|except|finally|raise|with|as|pass|break|continue|and|or|not|in|is|None|True|False|lambda|yield|global|nonlocal|assert|del|print|async|await';

  let keywords: string;
  if (lang === 'python' || lang === 'py') {
    keywords = pyKeywords;
  } else {
    keywords = jsKeywords;
  }

  const tokens: { text: string; color: string }[] = [];
  
  // Build regex parts
  const isPy = (lang === 'python' || lang === 'py');
  const commentPart = isPy ? '(#[^\n]*)' : '(//[^\n]*|/\*[\s\S]*?\*/)';
  const stringPart = '("(?:[^"\\\\]|\\\\.)*"|\'(?:[^\'\\\\]|\\\\.)*\'|`(?:[^`\\\\]|\\\\.)*`)';
  const keywordPart = '(\\b(?:' + keywords + ')\\b)';
  const numberPart = '(\\b\\d+\\.?\\d*\\b)';
  const funcPart = '(\\b[a-zA-Z_]\\w*\\b)\\s*(?=\\()';

  const tokenPattern = new RegExp(
    commentPart + '|' + stringPart + '|' + keywordPart + '|' + numberPart + '|' + funcPart,
    'g'
  );

  let lastIndex = 0;
  let match;
  while ((match = tokenPattern.exec(code)) !== null) {
    if (match.index > lastIndex) {
      tokens.push({ text: code.slice(lastIndex, match.index), color: defaultColor });
    }
    if (match[1]) {
      tokens.push({ text: match[1], color: commentColor });
    } else if (match[2]) {
      tokens.push({ text: match[2], color: stringColor });
    } else if (match[3]) {
      tokens.push({ text: match[3], color: keywordColor });
    } else if (match[4]) {
      tokens.push({ text: match[4], color: numberColor });
    } else if (match[5]) {
      tokens.push({ text: match[5], color: funcColor });
      lastIndex = match.index + match[5].length;
      continue;
    }
    lastIndex = match.index + match[0].length;
  }
  if (lastIndex < code.length) {
    tokens.push({ text: code.slice(lastIndex), color: defaultColor });
  }

  if (tokens.length === 0) {
    return [<Text key={keyPrefix + '-hl0'} style={{ color: defaultColor }}>{code}</Text>];
  }

  return tokens.map((t, idx) => (
    <Text key={keyPrefix + '-hl' + idx} style={{ color: t.color }}>{t.text}</Text>
  ));
}

// ===== Copy to Clipboard Helper =====
async function copyToClipboard(text: string) {
  try {
    if (Platform.OS === 'web' && typeof navigator !== 'undefined' && navigator.clipboard) {
      await navigator.clipboard.writeText(text);
    } else {
      await Clipboard.setStringAsync(text);
    }
  } catch (e) {
    try {
      if (Platform.OS !== 'web') {
        await Clipboard.setStringAsync(text);
      }
    } catch (_) {}
  }
}

// ===== Copy Button Component =====
function CodeCopyButton({ text, isDark }: { text: string; isDark: boolean }) {
  const [copied, setCopied] = React.useState(false);
  const timerRef = React.useRef<any>(null);
  const handleCopy = async () => {
    await copyToClipboard(text);
    setCopied(true);
    if (timerRef.current) clearTimeout(timerRef.current);
    timerRef.current = setTimeout(() => setCopied(false), 1500);
  };
  return (
    <TouchableOpacity
      onPress={handleCopy}
      style={{
        position: 'absolute', top: 6, right: 6, zIndex: 10,
        flexDirection: 'row', alignItems: 'center',
        backgroundColor: isDark ? 'rgba(255,255,255,0.1)' : 'rgba(0,0,0,0.06)',
        borderRadius: 6, paddingHorizontal: 8, paddingVertical: 3,
      }}
    >
      <Text style={{ fontSize: 11, color: isDark ? '#9ca3af' : '#6b7280' }}>
        {copied ? '✓ 已复制' : '📋 复制'}
      </Text>
    </TouchableOpacity>
  );
}

function TableCopyButton({ headers, rows, isDark }: { headers: string[]; rows: string[][]; isDark: boolean }) {
  const [copied, setCopied] = React.useState(false);
  const timerRef = React.useRef<any>(null);
  const handleCopy = async () => {
    const headerLine = '| ' + headers.join(' | ') + ' |';
    const sepLine = '| ' + headers.map(() => '---').join(' | ') + ' |';
    const dataLines = rows.map(r => '| ' + r.join(' | ') + ' |');
    const md = [headerLine, sepLine, ...dataLines].join('\n');
    await copyToClipboard(md);
    setCopied(true);
    if (timerRef.current) clearTimeout(timerRef.current);
    timerRef.current = setTimeout(() => setCopied(false), 1500);
  };
  return (
    <TouchableOpacity
      onPress={handleCopy}
      style={{
        flexDirection: 'row', alignItems: 'center',
        backgroundColor: isDark ? 'rgba(255,255,255,0.1)' : 'rgba(0,0,0,0.06)',
        borderRadius: 6, paddingHorizontal: 8, paddingVertical: 3,
      }}
    >
      <Text style={{ fontSize: 11, color: isDark ? '#9ca3af' : '#6b7280' }}>
        {copied ? '✓ 已复制' : '📋 复制表格'}
      </Text>
    </TouchableOpacity>
  );
}

// ============ Markdown Preview Modal (App内渲染.md) ============
function simpleMdToElements(md: string, isDark: boolean): React.ReactNode[] {
  const els: React.ReactNode[] = [];
  const lines = md.split('\n');
  let i = 0;
  const tc = isDark ? '#e5e7eb' : '#1f2937';
  const sc = isDark ? '#9ca3af' : '#6b7280';
  const cb = isDark ? '#1e293b' : '#f1f5f9';

  const parseInline = (text: string, key: string): React.ReactNode => {
    const parts: React.ReactNode[] = [];
    let remaining = text;
    let k = 0;
    while (remaining.length > 0) {
      const boldM = remaining.match(/\*\*(.+?)\*\*/);
      const italicM = remaining.match(/(^|[^*])\*([^*]+?)\*([^*]|$)/);
      const codeM = remaining.match(/`([^`]+)`/);
      const linkM = remaining.match(/\[([^\]]+)\]\(([^)]+)\)/);
      type M = { type: string; m: RegExpMatchArray; idx: number };
      const candidates: M[] = [];
      if (boldM && boldM.index !== undefined) candidates.push({ type: 'bold', m: boldM, idx: boldM.index });
      if (italicM && italicM.index !== undefined) candidates.push({ type: 'italic', m: italicM, idx: italicM.index + (italicM[1] || '').length });
      if (codeM && codeM.index !== undefined) candidates.push({ type: 'code', m: codeM, idx: codeM.index });
      if (linkM && linkM.index !== undefined) candidates.push({ type: 'link', m: linkM, idx: linkM.index });
      candidates.sort((a, b) => a.idx - b.idx);
      const first = candidates[0];
      if (!first) {
        if (remaining) parts.push(<Text key={`${key}-t${k}`} style={{ color: tc }}>{remaining}</Text>);
        break;
      }
      if (first.idx > 0) parts.push(<Text key={`${key}-pre${k}`} style={{ color: tc }}>{remaining.slice(0, first.idx)}</Text>);
      if (first.type === 'bold') {
        parts.push(<Text key={`${key}-b${k}`} style={{ color: tc, fontWeight: '700' }}>{first.m[1]}</Text>);
        remaining = remaining.slice(first.idx + first.m[0].length);
      } else if (first.type === 'italic') {
        parts.push(<Text key={`${key}-i${k}`} style={{ color: tc, fontStyle: 'italic' }}>{first.m[2]}</Text>);
        remaining = remaining.slice(first.idx + first.m[2].length + 2);
      } else if (first.type === 'code') {
        parts.push(<Text key={`${key}-c${k}`} style={{ color: '#e11d48', backgroundColor: cb, paddingHorizontal: 4, paddingVertical: 1, borderRadius: 4, fontSize: 13 }}>{first.m[1]}</Text>);
        remaining = remaining.slice(first.idx + first.m[0].length);
      } else if (first.type === 'link') {
        const u = first.m[2];
        // [FIX] 视频链接使用内联播放器，不跳外部浏览器
        if (/\.(mp4|webm|mov|m3u8)(\?|$)/i.test(u)) {
          parts.push(<View key={`${key}-vid${k}`} style={{ marginVertical: 6 }}><VideoPlayerInline src={u} videoKey={`${key}-vid${k}`} /></View>);
        } else {
          const fileFi = pickFileInfo(u);
          if (fileFi) {
            // 文件链接：显示文件卡片（图标 + 文件名 + 大小 + 下载按钮）
            parts.push(<View key={`${key}-l${k}`} style={{ marginVertical: 6 }}><FileDownloadCard url={u} /></View>);
          } else {
            // 普通链接：蓝色下划线文字
            parts.push(<Text key={`${key}-l${k}`} style={{ color: '#2563eb', textDecorationLine: 'underline' }} onPress={() => openExternally(u)}>{first.m[1]}</Text>);
          }
        }
        remaining = remaining.slice(first.idx + first.m[0].length);
      }
      k++;
    }
    return parts.length <= 1 ? (parts[0] || <></>) : <>{parts}</>;
  };

  while (i < lines.length) {
    const line = lines[i];
    if (line.startsWith('```')) {
      const codeLines: string[] = [];
      i++;
      while (i < lines.length && !lines[i].startsWith('```')) { codeLines.push(lines[i]); i++; }
      if (i < lines.length) i++;
      {
        const codeText = codeLines.join('\n');
        els.push(<View key={`cb-${els.length}`} style={{ backgroundColor: cb, borderRadius: 8, padding: 10, marginVertical: 6, position: 'relative' }}>
          <CodeCopyButton text={codeText} isDark={isDark} />
          <ScrollView horizontal showsHorizontalScrollIndicator={false}>
            <Text style={{ color: isDark ? '#e2e8f0' : '#1e293b', fontSize: 13, fontFamily: Platform.OS === 'ios' ? 'Menlo' : 'monospace' }} selectable>{highlightCode(codeText, '', isDark, `cb-${els.length}`)}</Text>
          </ScrollView>
        </View>);
      }
      continue;
    }
    const hM = line.match(/^(#{1,6})\s+(.+)$/);
    if (hM) {
      const lv = hM[1].length;
      const sz = [22, 20, 18, 16, 15, 14];
      els.push(<Text key={`h-${els.length}`} style={{ color: tc, fontWeight: '700', fontSize: sz[lv - 1] || 14, marginTop: 12, marginBottom: 4 }} selectable>{parseInline(hM[2], `h${els.length}`)}</Text>);
      i++; continue;
    }
    const ulM = line.match(/^[-*+]\s+(.+)$/);
    if (ulM) {
      els.push(<View key={`ul-${els.length}`} style={{ flexDirection: 'row', marginTop: 4, marginBottom: 4 }}><Text style={{ color: sc, fontSize: 14, marginRight: 8, marginTop: 2 }}>•</Text><Text style={{ color: tc, fontSize: 14, flex: 1 }} selectable>{parseInline(ulM[1], `ul${els.length}`)}</Text></View>);
      i++; continue;
    }
    const olM = line.match(/^(\d+)\.\s+(.+)$/);
    if (olM) {
      els.push(<View key={`ol-${els.length}`} style={{ flexDirection: 'row', marginTop: 4, marginBottom: 4 }}><Text style={{ color: sc, fontSize: 14, marginRight: 8, minWidth: 20 }}>{olM[1]}.</Text><Text style={{ color: tc, fontSize: 14, flex: 1 }} selectable>{parseInline(olM[2], `ol${els.length}`)}</Text></View>);
      i++; continue;
    }
    if (line.startsWith('> ')) {
      els.push(<View key={`bq-${els.length}`} style={{ borderLeftWidth: 3, borderLeftColor: '#9ca3af', paddingLeft: 10, marginVertical: 4 }}><Text style={{ color: sc, fontSize: 14, fontStyle: 'italic' }} selectable>{parseInline(line.slice(2), `bq${els.length}`)}</Text></View>);
      i++; continue;
    }
    if (/^[-*_]{3,}$/.test(line.trim())) {
      els.push(<View key={`hr-${els.length}`} style={{ height: 1, backgroundColor: isDark ? '#374151' : '#e5e7eb', marginVertical: 8 }} />);
      i++; continue;
    }
    if (line.trim() === '') { i++; continue; }
    els.push(<Text key={`p-${els.length}`} style={{ color: tc, fontSize: 14, lineHeight: 22, marginVertical: 3 }} selectable>{parseInline(line, `p${els.length}`)}</Text>);
    i++;
  }
  return els;
}

function MarkdownPreviewModal({ url, onClose }: { url: string; onClose: () => void }) {
  const [content, setContent] = React.useState('');
  const [loading, setLoading] = React.useState(true);
  const [error, setError] = React.useState('');
  const fileName = decodeURIComponent(url.split('?')[0].split('/').pop() || 'file.md').replace(/^upload_/, '');

  React.useEffect(() => {
    let cancelled = false;
    fetch(url).then(r => { if (!r.ok) throw new Error('HTTP ' + r.status); return r.text(); })
      .then(text => { if (!cancelled) { setContent(text); setLoading(false); } })
      .catch(e => { if (!cancelled) { setError(e.message); setLoading(false); } });
    return () => { cancelled = true; };
  }, [url]);

  return (
    <Modal visible={true} animationType="slide" onRequestClose={onClose} transparent>
      <View style={{ flex: 1, backgroundColor: 'rgba(0,0,0,0.4)', justifyContent: 'flex-end' }}>
        <View style={{ backgroundColor: '#ffffff', borderTopLeftRadius: 16, borderTopRightRadius: 16, maxHeight: '85%', paddingBottom: 20 }}>
          <View style={{ flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', paddingHorizontal: 16, paddingVertical: 12, borderBottomWidth: 1, borderBottomColor: '#f1f5f9' }}>
            <Text style={{ fontSize: 16, fontWeight: '700', color: '#1f2937', flex: 1 }} numberOfLines={1}>{fileName}</Text>
            <TouchableOpacity onPress={onClose} style={{ padding: 4, marginLeft: 8 }}><Text style={{ fontSize: 22, color: '#6b7280' }}>✕</Text></TouchableOpacity>
          </View>
          <ScrollView style={{ maxHeight: '75%' }} contentContainerStyle={{ padding: 16 }}>
            {loading ? <ActivityIndicator size="large" color="#3b82f6" style={{ marginVertical: 40 }} />
              : error ? <Text style={{ color: '#ef4444', textAlign: 'center', marginVertical: 20 }}>加载失败：{error}</Text>
              : <>{simpleMdToElements(content, false)}</>}
          </ScrollView>
        </View>
      </View>
    </Modal>
  );
}

function FileDownloadCard({ url }: { url: string }) {
  const fi = pickFileInfo(url);
  const [mdUrl, setMdUrl] = React.useState<string | null>(null);
  const [size, setSize] = React.useState<number | null>(null);
  const [downloading, setDownloading] = React.useState(false);
  const [progress, setProgress] = React.useState(0);

  React.useEffect(() => {
    let alive = true;
    if (fi) fetchFileSize(url).then((n) => { if (alive) setSize(n); });
    return () => { alive = false; };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [url]);

  if (!fi) return null;

  const onPreview = () => {
    if (fi.ext === '.md') { setMdUrl(url); return; }
    // 原生包走 QuickLook/系统预览器；纯 JS 包自动兜底为下载+分享面板
    previewFile(url);
  };

  const onDownload = async () => {
    if (downloading) return;
    setDownloading(true);
    setProgress(0);
    try {
      await downloadAndShare(url, (r) => setProgress(r));
    } finally {
      // 分享面板关闭后稍作延时复位，避免进度条瞬间闪烁
      setTimeout(() => { setDownloading(false); setProgress(0); }, 400);
    }
  };

  const sizeText = size != null ? formatFileSize(size) : '';

  return (
    <>
    <View style={{ marginVertical: 6, backgroundColor: '#f4f6fb',
        borderWidth: 1, borderColor: '#e3e8f2', borderRadius: 12, padding: 12 }}>
      <View style={{ flexDirection: 'row', alignItems: 'center' }}>
        <View style={{ width: 40, height: 40, borderRadius: 10, backgroundColor: fi.info.color,
          alignItems: 'center', justifyContent: 'center', marginRight: 12 }}>
          <Text style={{ fontSize: 20 }}>{fi.info.icon}</Text>
        </View>
        <View style={{ flex: 1, minWidth: 0 }}>
          <Text numberOfLines={1} style={{ fontSize: 14, fontWeight: '600', color: '#1f2937' }}>{fi.name}</Text>
          <Text style={{ fontSize: 12, color: '#94a3b8', marginTop: 2 }} numberOfLines={1}>
            {fi.info.label}{sizeText ? ' · ' + sizeText : ''}
          </Text>
        </View>
      </View>
      {downloading ? (
        <View style={{ marginTop: 10 }}>
          <View style={{ height: 5, borderRadius: 3, backgroundColor: '#e2e8f0', overflow: 'hidden' }}>
            <View style={{ height: 5, borderRadius: 3, backgroundColor: fi.info.color,
              width: `${Math.round(progress * 100)}%` }} />
          </View>
          <View style={{ flexDirection: 'row', alignItems: 'center', justifyContent: 'center', marginTop: 8 }}>
            <ActivityIndicator size="small" color={fi.info.color} style={{ marginRight: 6 }} />
            <Text style={{ fontSize: 12, color: '#64748b' }}>
              {progress >= 1 ? '正在打开…' : `下载中 ${Math.round(progress * 100)}%`}
            </Text>
          </View>
        </View>
      ) : (
        <View style={{ flexDirection: 'row', marginTop: 10 }}>
          <TouchableOpacity activeOpacity={0.7} onPress={onPreview}
            style={{ flex: 1, flexDirection: 'row', alignItems: 'center', justifyContent: 'center',
              paddingVertical: 8, borderRadius: 8, backgroundColor: fi.info.color, marginRight: 8 }}>
            <Text style={{ color: '#fff', fontSize: 13, fontWeight: '600' }}>
              {fi.ext === '.md' ? '阅读' : '预览'}
            </Text>
          </TouchableOpacity>
          <TouchableOpacity activeOpacity={0.7} onPress={onDownload}
            style={{ flex: 1, flexDirection: 'row', alignItems: 'center', justifyContent: 'center',
              paddingVertical: 8, borderRadius: 8, backgroundColor: '#fff',
              borderWidth: 1, borderColor: fi.info.color }}>
            <Text style={{ fontSize: 18, color: fi.info.color, marginRight: 4 }}>⬇</Text>
            <Text style={{ color: fi.info.color, fontSize: 13, fontWeight: '600' }}>下载</Text>
          </TouchableOpacity>
        </View>
      )}
    </View>
    {mdUrl ? <MarkdownPreviewModal url={mdUrl} onClose={() => setMdUrl(null)} /> : null}
    </>
  );
}

// 把一段文本中的 markdown 链接 [txt](url) 与裸 URL 拆成可点击节点
function renderLinkedText(text: string, keyBase: string, isDark: boolean, onMdLink?: (url: string) => void): React.ReactNode {
  const linkColor = '#2563eb';
  const tokenRe = /\[([^\]]+)\]\((https?:\/\/[^\s)]+)\)|(https?:\/\/[^\s)\]]+)/g;
  const nodes: React.ReactNode[] = [];
  let last = 0; let mm: RegExpExecArray | null; let k = 0;
  while ((mm = tokenRe.exec(text)) !== null) {
    if (mm.index > last) nodes.push(<Text key={`${keyBase}-t${k}`}>{text.slice(last, mm.index)}</Text>);
    const label = mm[1] || mm[2];
    const url = mm[2] || mm[0];
    if (onMdLink && /\.md(\?|$)/i.test(url)) {
      nodes.push(
        <Text key={`${keyBase}-l${k}`} style={{ color: linkColor, textDecorationLine: 'underline' }}
          onPress={() => { onMdLink(url); }}>{label}</Text>
      );
    } else if (pickFileInfo(url)) {
      nodes.push(
        <Text key={`${keyBase}-l${k}`} style={{ color: linkColor, textDecorationLine: 'underline' }}
          onPress={() => { downloadAndShare(url); }}>{label}</Text>
      );
    } else {
      nodes.push(
        <Text key={`${keyBase}-l${k}`} style={{ color: linkColor, textDecorationLine: 'underline' }}
          onPress={() => { openExternally(url); }}>{label}</Text>
      );
    }
    last = mm.index + mm[0].length; k++;
  }
  if (last < text.length) nodes.push(<Text key={`${keyBase}-tE`}>{text.slice(last)}</Text>);
  return nodes.length ? <React.Fragment key={keyBase}>{nodes}</React.Fragment> : <>{text}</>;
}

function extractHtmlTags(text: string): React.ReactNode[] {
  const parts: React.ReactNode[] = [];
  const mdImgConverted = text.replace(/!\[([^\]]*)\]\(([^)]+)\)/g, '<img src="$2" alt="$1" />');
  const allMatches: { type: string; content: string; index: number }[] = [];
  let m;
  const imgRe = /<img[^>]+>/gi;
  while ((m = imgRe.exec(mdImgConverted)) !== null) { allMatches.push({ type: 'img', content: m[0], index: m.index }); }
  const vidRe = /<video[^>]*>[\s\S]*?<\/video>|<video[^>]+>/gi;
  while ((m = vidRe.exec(mdImgConverted)) !== null) { allMatches.push({ type: 'video', content: m[0], index: m.index }); }
  allMatches.sort((a, b) => a.index - b.index);
  let pos = 0;
  let keyIdx = 0;
  for (const match of allMatches) {
    if (match.index > pos) {
      parts.push(mdImgConverted.slice(pos, match.index) as any);
    }
    if (match.type === 'img') parts.push(renderImgTag(match.content, `img-${keyIdx++}`));
    else parts.push(renderVideoTag(match.content, `vid-${keyIdx++}`));
    pos = match.index + match.content.length;
  }
  // [FIX] 只在真正有 img/video 标签时才返回非空，否则返回空数组
  // 这样普通文本段落会走 else 分支（简单 Text 渲染），不会被兜底 string 阻塞卡片提取
  return allMatches.length > 0 ? parts : [];
}

const isTableSeparator = (line: string): boolean => {
  return /^\|?\s*:?-{2,}:?\s*(\|\s*:?-{2,}:?\s*)*\|?\s*$/.test(line.trim());
};

const parseAlignments = (line: string): ('left' | 'center' | 'right')[] => {
  const cells = line.trim().replace(/^\||\|$/g, '').split('|');
  return cells.map(cell => {
    const trimmed = cell.trim();
    if (trimmed.startsWith(':') && trimmed.endsWith(':')) return 'center';
    if (trimmed.endsWith(':')) return 'right';
    return 'left';
  });
};

const parseTableCells = (line: string): string[] => {
  let trimmed = line.trim();
  if (trimmed.startsWith('|')) trimmed = trimmed.slice(1);
  if (trimmed.endsWith('|')) trimmed = trimmed.slice(0, -1);
  return trimmed.split('|').map(cell => cell.trim());
};

interface RenderCtx {
  isDark: boolean;
  textColor: string;
  codeBg: string;
  renderInline: (text: string, key: string) => React.ReactNode;
  availW: number;
}

function textVisualLen(s: string): number {
  // 中文/全角按 2 宽度估算
  let n = 0;
  for (const ch of s) {
    n += /[\u3000-\u9fff\uff00-\uffef]/.test(ch) ? 2 : 1;
  }
  return n;
}

function computeColWidths(headers: string[], rows: string[][], maxColW: number, minColW: number): number[] {
  const n = headers.length;
  const lens: number[] = headers.map(h => textVisualLen(h));
  for (const r of rows) {
    for (let i = 0; i < n; i++) {
      const l = textVisualLen(r[i] || '');
      if (l > (lens[i] || 0)) lens[i] = l;
    }
  }
  // 字号 sm=13：每宽单位约 6.2px（中文 visual=2 -> 约 12.4px/字），单元格内边距 18px
  return lens.map(l => {
    let w = Math.ceil(l * 6.2) + 18;
    if (w < minColW) w = minColW;
    if (w > maxColW) w = maxColW;
    return w;
  });
}

function renderTable(headerLine: string, lines: string[], startIdx: number, ctx: RenderCtx): { element: React.ReactNode; consumed: number } {
  if (startIdx + 1 >= lines.length) return { element: null, consumed: 0 };
  const sepLine = lines[startIdx + 1];
  if (!isTableSeparator(sepLine)) return { element: null, consumed: 0 };

  const alignments = parseAlignments(sepLine);
  const headers = parseTableCells(headerLine);
  const { isDark, textColor, renderInline } = ctx;
  const headerBg = isDark ? '#2d3748' : '#f7f7f5';
  const borderColor = isDark ? '#4a5568' : '#e2e8f0';
  const hintColor = isDark ? '#94a3b8' : '#9ca3af';

  const dataRowsRaw: string[][] = [];
  let consumed = 2;
  for (let j = startIdx + 2; j < lines.length; j++) {
    const row = lines[j].trim();
    if (row === '' || !row.includes('|')) break;
    dataRowsRaw.push(parseTableCells(row));
    consumed++;
  }
  // 行单元格数对齐表头：缺补空串，多的截断
  const dataRows = dataRowsRaw.map(r => {
    const out = r.slice(0, headers.length);
    while (out.length < headers.length) out.push('');
    return out;
  });

  // 可用宽度：由容器 onLayout 实测传入（首帧为保守屏宽估算）
  const availW = ctx.availW;
  const colW = computeColWidths(headers, dataRows, 190, 64);
  const totalW = colW.reduce((a, b) => a + b, 0) + 4;
  // 容差 32px：估算临界窄表（总宽仅超十几 px）归入 flex 自适应一屏；真宽表超数百 px 不受影响
  const scrollable = totalW > availW + 48;

  // Extract plain text for copy
  const plainHeaders = headers.map(h => h.replace(/[*_`]/g, ''));
  const plainRows = dataRows.map(r => r.map(c => c.replace(/[*_`]/g, '')));

  // 纯文本降级（渲染异常/错误边界时使用），保证表格内容永远不会整块消失
  const fallbackTable = (
    <View key={`table-fb-${startIdx}`} style={{ width: '100%', marginVertical: Spacing.sm }}>
      <Text selectable style={{ fontSize: 12, color: textColor, lineHeight: 19 }}>
        {[plainHeaders.join('  '), ...plainRows.map(r => r.join('  '))].join('\n')}
      </Text>
    </View>
  );

  return {
    element: (
      <TableErrorBoundary key={`teb-${startIdx}`} fallback={fallbackTable}>
        <TableBlock
          key={`table-${startIdx}`}
          startIdx={startIdx}
          headers={headers}
          dataRows={dataRows}
          colW={colW}
          totalW={totalW}
          scrollable={scrollable}
          alignments={alignments}
          isDark={isDark}
          renderInline={renderInline}
          plainHeaders={plainHeaders}
          plainRows={plainRows}
          borderColor={borderColor}
          headerBg={headerBg}
          hintColor={hintColor}
        />
      </TableErrorBoundary>
    ),
    consumed,
  };
}

// 独立表格组件：把横向 ScrollView 的高度状态隔离在单表内部，
// 并在宽表时用"隐藏实测 + 估算初值"给 ScrollView 锁定确定高度，
// 根治横向 ScrollView 在 FlatList 行回收时高度坍缩为 0（表格闪一下消失）的问题。
interface TableBlockProps {
  startIdx: number;
  headers: string[];
  dataRows: string[][];
  colW: number[];
  totalW: number;
  scrollable: boolean;
  alignments: ('left' | 'center' | 'right')[];
  isDark: boolean;
  renderInline: (text: string, key: string) => React.ReactNode;
  plainHeaders: string[];
  plainRows: string[][];
  borderColor: string;
  headerBg: string;
  hintColor: string;
}

function TableBlock(props: TableBlockProps) {
  const { startIdx, headers, dataRows, colW, totalW, scrollable, alignments,
    isDark, renderInline, plainHeaders, plainRows, borderColor, headerBg, hintColor } = props;

  // 首帧保守高度估算：表头约 37px、每数据行约 35px（单行文本 13px+上下padding 12+边框，给足冗余防裁切），
  // 保证 FlatList 行回收重挂时滚动容器高度永不为 0。实测高度回来后用 max 只增不减，避免抖动。
  const estHeight = 37 + dataRows.length * 35 + 2;
  const [measuredH, setMeasuredH] = React.useState<number>(estHeight);

  const cellStyle = (prefix: string, ci: number, isHeaderCell: boolean) => ({
    width: colW[ci],
    minWidth: colW[ci],
    flexShrink: 0,
    paddingHorizontal: 10,
    paddingVertical: isHeaderCell ? 8 : 6,
    alignItems: (alignments[ci] === 'center' ? 'center' : alignments[ci] === 'right' ? 'flex-end' : 'flex-start') as any,
    borderRightWidth: ci < headers.length - 1 ? 0.5 : 0,
    borderRightColor: borderColor,
  });

  const buildBody = (prefix: string, measure: boolean) => (
    <View
      key={`${prefix}-wrap`}
      onLayout={measure ? (e) => {
        // 只构建一次 body，直接在真实可见内容上实测高度（不再用 opacity/absolute 隐藏层）
        const h = Math.ceil(e.nativeEvent.layout.height);
        if (h > 0) setMeasuredH((prev) => (Math.abs(h - prev) >= 2 ? Math.max(prev, h) : prev));
      } : undefined}
      style={{ borderWidth: 1, borderColor, borderRadius: BorderRadius.md, overflow: 'hidden', flexDirection: 'column', width: scrollable ? totalW : '100%' as any, flexShrink: 0 }}
    >
      <View style={{ flexDirection: 'row', backgroundColor: headerBg, borderBottomWidth: 1, borderBottomColor: borderColor }}>
        {headers.map((cell, ci) => (
          <View key={`${prefix}-th-${ci}`} style={cellStyle(prefix, ci, true)}>
            <Text selectable style={{ fontSize: FontSize.sm, fontWeight: '700', color: textColor, flexWrap: 'wrap', width: '100%' }}>{renderInline(cell, `${prefix}-th-${ci}`)}</Text>
          </View>
        ))}
      </View>
      {dataRows.map((row, ri) => (
        <View key={`${prefix}-tr-${ri}`} style={{ flexDirection: 'row', flexShrink: 0, borderBottomWidth: ri < dataRows.length - 1 ? 0.5 : 0, borderBottomColor: borderColor }}>
          {row.map((cell, ci) => (
            <View key={`${prefix}-td-${ri}-${ci}`} style={cellStyle(prefix, ci, false)}>
              <Text selectable style={{ fontSize: FontSize.sm, color: textColor, flexWrap: 'wrap', width: '100%' }}>{renderInline(cell, `${prefix}-td-${ri}-${ci}`)}</Text>
            </View>
          ))}
        </View>
      ))}
    </View>
  );

  return (
    <View style={{ width: '100%', minWidth: 0, maxWidth: '100%', marginVertical: Spacing.sm, flexShrink: 0 }} className="md-table-scroll">
      <View style={{ flexDirection: 'row', justifyContent: 'flex-end', marginTop: 4 }}>
        <TableCopyButton headers={plainHeaders} rows={plainRows} isDark={isDark} />
      </View>
      {Platform.OS === 'web' ? (
        <View style={{ width: '100%', maxWidth: '100%', minWidth: 0, flexShrink: 1, overflowX: 'auto' } as any}>
          {buildBody('w' + startIdx, false)}
        </View>
      ) : scrollable ? (
        <>
          <ScrollView
            horizontal
            showsHorizontalScrollIndicator
            directionalLockEnabled
            alwaysBounceHorizontal={false}
            alwaysBounceVertical={false}
            style={{ width: '100%', height: measuredH }}
            contentContainerStyle={{ flexGrow: 0, flexShrink: 0, alignItems: 'flex-start' }}
          >
            {buildBody('s' + startIdx, true)}
          </ScrollView>
          <Text style={{ fontSize: 11, color: hintColor, marginTop: 4, width: '100%', textAlign: 'right' }}>左右滑动查看更多列 ›</Text>
        </>
      ) : (
        buildBody('n' + startIdx, false)
      )}
    </View>
  );
}

// ===== Main component =====

export const MarkdownRenderer: React.FC<MarkdownRendererProps> = ({ content, isDark }) => {
  const [mdPreviewUrl, setMdPreviewUrl] = React.useState<string | null>(null);
  const [renderError, setRenderError] = React.useState<string | null>(null);
  const { decodedContent, parseError } = (() => {
    try {
      const dc = decodeURIComponent(content || '');
      return { decodedContent: dc, parseError: null };
    } catch {
      return { decodedContent: content || '', parseError: null };
    }
  })();

  // Trim trailing whitespace/newlines to prevent bubble from being too tall
  const trimmedContent = decodedContent.replace(/\s+$/, '');
  const lines = trimmedContent.split('\n');
  const elements: React.ReactNode[] = [];
  let inCodeBlock = false;
  let codeContent = '';
  let codeLang = '';
  let inList = false;

  const textColor = isDark ? Colors.textInverse : Colors.text;
  const codeBg = isDark ? '#1e1e1e' : '#f5f5f5';

  // Paragraph-specific inline renderer: file links render as blue text only (cards rendered separately below)
  const renderInlineForParagraph = (text: string, key: string): React.ReactNode => {
    const parts: React.ReactNode[] = [];
    let remaining = text;
    let k = 0;
    while (remaining.length > 0) {
      const boldM = remaining.match(/\*\*(.+?)\*\*/);
      const italicM = remaining.match(/(^|[^*])\*([^*]+?)\*([^*]|$)/);
      const codeM = remaining.match(/\`([^\`]+)\`/);
      const linkM = remaining.match(/\[([^\]]+)\]\(([^)]+)\)/);
      type M2 = { type: string; m: RegExpMatchArray; idx: number };
      const candidates: M2[] = [];
      if (boldM && boldM.index !== undefined) candidates.push({ type: 'bold', m: boldM, idx: boldM.index });
      if (italicM && italicM.index !== undefined) candidates.push({ type: 'italic', m: italicM, idx: italicM.index + (italicM[1] || '').length });
      if (codeM && codeM.index !== undefined) candidates.push({ type: 'code', m: codeM, idx: codeM.index });
      if (linkM && linkM.index !== undefined) candidates.push({ type: 'link', m: linkM, idx: linkM.index });
      candidates.sort((a, b) => a.idx - b.idx);
      const first = candidates[0];
      if (!first) {
        if (remaining) parts.push(<Text key={`${key}-pt${k}`} style={{ color: textColor }}>{remaining}</Text>);
        break;
      }
      if (first.idx > 0) parts.push(<Text key={`${key}-ppre${k}`} style={{ color: textColor }}>{remaining.slice(0, first.idx)}</Text>);
      if (first.type === 'bold') {
        parts.push(<Text key={`${key}-pb${k}`} style={{ color: textColor, fontWeight: '700' }}>{first.m[1]}</Text>);
        remaining = remaining.slice(first.idx + first.m[0].length);
      } else if (first.type === 'italic') {
        parts.push(<Text key={`${key}-pi${k}`} style={{ color: textColor, fontStyle: 'italic' }}>{first.m[2]}</Text>);
        remaining = remaining.slice(first.idx + first.m[2].length + 2);
      } else if (first.type === 'code') {
        parts.push(<Text key={`${key}-pc${k}`} style={{ color: '#e11d48', backgroundColor: codeBg, paddingHorizontal: 4, paddingVertical: 1, borderRadius: 4, fontSize: 13 }}>{first.m[1]}</Text>);
        remaining = remaining.slice(first.idx + first.m[0].length);
      } else if (first.type === 'link') {
        const u = first.m[2];
        // [FIX] 视频链接：段落文字里跳过，播放器在段落下方块级渲染
        if (/\.(mp4|webm|mov|m3u8)(\?|$)/i.test(u)) {
          remaining = remaining.slice(first.idx + first.m[0].length);
          continue;
        }
        // [FIX] 文件链接（Office/PDF/zip 等）：段落文字里跳过，FileDownloadCard 在段落下方块级渲染，
        // 预览/下载全部 App 内闭环，绝不跳外部浏览器
        if (pickFileInfo(u) && !/\.md(\?|$)/i.test(u)) {
          remaining = remaining.slice(first.idx + first.m[0].length);
          continue;
        }
        if (/\.md(\?|$)/i.test(u)) {
          parts.push(<Text key={`${key}-pml${k}`} style={{ color: '#2563eb', textDecorationLine: 'underline' }} onPress={() => { setMdPreviewUrl(u); }}>{first.m[1]}</Text>);
        } else {
          // 仅真正的普通网页链接才允许外部浏览器
          parts.push(<Text key={`${key}-pl${k}`} style={{ color: '#2563eb', textDecorationLine: 'underline' }} onPress={() => { openExternally(u); }}>{first.m[1]}</Text>);
        }
        remaining = remaining.slice(first.idx + first.m[0].length);
      }
      k++;
    }
    return parts.length <= 1 ? (parts[0] || <></>) : <>{parts}</>;
  };

  const renderInline = (text: string, key: string): React.ReactNode => {
    // Use earliest-match-wins approach (same proven logic as parseInline in simpleMdToElements)
    const parts: React.ReactNode[] = [];
    let remaining = text;
    let k = 0;
    while (remaining.length > 0) {
      const boldM = remaining.match(/\*\*(.+?)\*\*/);
      const italicM = remaining.match(/(^|[^*])\*([^*]+?)\*([^*]|$)/);
      const codeM = remaining.match(/\`([^\`]+)\`/);
      const linkM = remaining.match(/\[([^\]]+)\]\(([^)]+)\)/);
      type M = { type: string; m: RegExpMatchArray; idx: number };
      const candidates: M[] = [];
      if (boldM && boldM.index !== undefined) candidates.push({ type: 'bold', m: boldM, idx: boldM.index });
      if (italicM && italicM.index !== undefined) candidates.push({ type: 'italic', m: italicM, idx: italicM.index + (italicM[1] || '').length });
      if (codeM && codeM.index !== undefined) candidates.push({ type: 'code', m: codeM, idx: codeM.index });
      if (linkM && linkM.index !== undefined) candidates.push({ type: 'link', m: linkM, idx: linkM.index });
      candidates.sort((a, b) => a.idx - b.idx);
      const first = candidates[0];
      if (!first) {
        if (remaining) parts.push(<Text key={`${key}-t${k}`} style={{ color: textColor }}>{remaining}</Text>);
        break;
      }
      if (first.idx > 0) parts.push(<Text key={`${key}-pre${k}`} style={{ color: textColor }}>{remaining.slice(0, first.idx)}</Text>);
      if (first.type === 'bold') {
        parts.push(<Text key={`${key}-b${k}`} style={{ color: textColor, fontWeight: '700' }}>{first.m[1]}</Text>);
        remaining = remaining.slice(first.idx + first.m[0].length);
      } else if (first.type === 'italic') {
        parts.push(<Text key={`${key}-i${k}`} style={{ color: textColor, fontStyle: 'italic' }}>{first.m[2]}</Text>);
        remaining = remaining.slice(first.idx + first.m[2].length + 2);
      } else if (first.type === 'code') {
        parts.push(<Text key={`${key}-c${k}`} style={{ color: '#e11d48', backgroundColor: codeBg, paddingHorizontal: 4, paddingVertical: 1, borderRadius: 4, fontSize: 13 }}>{first.m[1]}</Text>);
        remaining = remaining.slice(first.idx + first.m[0].length);
      } else if (first.type === 'link') {
        const u = first.m[2];
        // [FIX] 视频链接使用内联播放器
        if (/\.(mp4|webm|mov|m3u8)(\?|$)/i.test(u)) {
          parts.push(<View key={`${key}-vid${k}`} style={{ marginVertical: 6 }}><VideoPlayerInline src={u} videoKey={`${key}-vid${k}`} /></View>);
        } else {
          const fileFi = pickFileInfo(u);
          if (fileFi) {
            parts.push(<View key={`${key}-l${k}`} style={{ marginVertical: 6 }}><FileDownloadCard url={u} /></View>);
          } else if (/\.md(\?|$)/i.test(u)) {
            parts.push(<Text key={`${key}-l${k}`} style={{ color: '#2563eb', textDecorationLine: 'underline' }} onPress={() => { setMdPreviewUrl(u); }}>{first.m[1]}</Text>);
          } else {
            parts.push(<Text key={`${key}-l${k}`} style={{ color: '#2563eb', textDecorationLine: 'underline' }} onPress={() => { openExternally(u); }}>{first.m[1]}</Text>);
          }
        }
        remaining = remaining.slice(first.idx + first.m[0].length);
      }
      k++;
    }
    return parts.length <= 1 ? (parts[0] || <></>) : <>{parts}</>;
  };

  // 宽度用屏宽常量估算（首帧定值）。禁止 onLayout setState 回写：原生 Yoga 布局会形成测量反馈环导致消息列表反复重排闪烁
  const availW = Math.max(200, Math.floor(Dimensions.get('window').width * 0.92) - 32);
  const ctx: RenderCtx = { isDark: !!isDark, textColor, codeBg, renderInline, availW };

  for (let i = 0; i < lines.length; i++) {
    const line = lines[i];

    // Code block
    if (line.startsWith('```')) {
      if (!inCodeBlock) {
        inCodeBlock = true;
        codeLang = line.slice(3).trim();
        codeContent = '';
      } else {
        inCodeBlock = false;
        elements.push(
          <View key={`code-${i}`} style={[styles.codeBlock, { backgroundColor: codeBg, position: 'relative' }]}>
            <CodeCopyButton text={codeContent} isDark={!!isDark} />
            {codeLang ? <Text style={[styles.codeLang, { color: isDark ? '#9b9b9b' : Colors.textSecondary }]}>{codeLang}</Text> : null}
            <ScrollView horizontal showsHorizontalScrollIndicator={false}>
              <Text style={[styles.codeText]} selectable>{highlightCode(codeContent, codeLang, !!isDark, `code-${i}`)}</Text>
            </ScrollView>
          </View>
        );
      }
      continue;
    }
    if (inCodeBlock) {
      codeContent += (codeContent ? '\n' : '') + line;
      continue;
    }

    // Table
    if (line.trim().includes('|') && i + 1 < lines.length && isTableSeparator(lines[i + 1])) {
      const tableResult = renderTable(line, lines, i, ctx);
      if (tableResult.element) {
        elements.push(tableResult.element);
        i += tableResult.consumed - 1;
        continue;
      }
    }

    // Empty line - use small spacing, don't add giant gaps
    if (line.trim() === '') {
      // Only add a small spacer if previous element wasn't already a spacer
      elements.push(<View key={`sp-${i}`} style={{ height: 4 }} />);
      continue;
    }

    // Headings
    if (line.startsWith('### ')) {
      elements.push(<Text key={`h3-${i}`} selectable style={[styles.h3, { color: textColor }]}>{renderInline(line.slice(4), `h3-${i}`)}</Text>);
    } else if (line.startsWith('## ')) {
      elements.push(<Text key={`h2-${i}`} selectable style={[styles.h2, { color: textColor }]}>{renderInline(line.slice(3), `h2-${i}`)}</Text>);
    } else if (line.startsWith('# ')) {
      elements.push(<Text key={`h1-${i}`} selectable style={[styles.h1, { color: textColor }]}>{renderInline(line.slice(2), `h1-${i}`)}</Text>);
    }
    // Blockquote
    else if (line.startsWith('> ')) {
      elements.push(
        <View key={`q-${i}`} style={[styles.quote, { borderLeftColor: Colors.primary }]}>
          <Text selectable style={[styles.quoteText, { color: isDark ? '#999' : Colors.textSecondary }]}>{renderInline(line.slice(2), `q-${i}`)}</Text>
        </View>
      );
    }
    // Unordered list
    else if (line.startsWith('- ') || line.startsWith('* ')) {
      if (!inList) { inList = true; }
      elements.push(
        <View key={`li-${i}`} style={styles.listItem}>
          <Text style={{ color: textColor, fontSize: FontSize.md, width: 16 }}>•</Text>
          <Text selectable style={{ color: textColor, fontSize: FontSize.md, flex: 1 }}>{renderInline(line.slice(2), `li-${i}`)}</Text>
        </View>
      );
    }
    // Ordered list
    else if (/^\d+\.\s/.test(line)) {
      const match = line.match(/^(\d+)\.\s(.*)$/);
      if (match) {
        elements.push(
          <View key={`ol-${i}`} style={styles.listItem}>
            <Text style={{ color: Colors.primary, fontSize: FontSize.md, fontWeight: '600', width: 24 }}>{match[1]}.</Text>
            <Text selectable style={{ color: textColor, fontSize: FontSize.md, flex: 1 }}>{renderInline(match[2], `ol-${i}`)}</Text>
          </View>
        );
      }
    }
    // Markdown image
    else if (/^!\[([^\]]*)\]\(([^)]+)\)/i.test(line.trim())) {
      const mdImgMatch = line.trim().match(/^!\[([^\]]*)\]\(([^)]+)\)/);
      if (mdImgMatch) {
        const alt = mdImgMatch[1] || '';
        const src = mdImgMatch[2];
        elements.push(
          <View key={`md-img-${i}`} style={styles.imgContainer}>
            <ZoomableImage uri={normalizeImageUrl(src)}>
              <Image source={{ uri: normalizeImageUrl(src) }} style={styles.img} resizeMode="cover" />
            </ZoomableImage>
            {alt ? <Text style={{ fontSize: 11, color: '#94a3b8', marginTop: 4, textAlign: 'center' }}>{alt}</Text> : null}
          </View>
        );
      }
    }
    // Video URL
    else if (/^https?:\/\/\S+\.(mp4|webm|mov)(\?\S*)?$/i.test(line.trim())) {
      elements.push(<VideoPlayerInline key={`vid-url-${i}`} src={line.trim()} videoKey={`vid-url-${i}`} />);
    }
    // 整行是 Office/文档下载链接 → 文件下载卡片
    else if (pickFileInfo(line.trim()) && /^https?:\/\/\S+$/.test(line.trim())) {
      inList = false;
      elements.push(<FileDownloadCard key={`file-${i}`} url={line.trim()} />);
    }
    // Normal text
    else {
      inList = false;
      if (/^<img[^>]+>/i.test(line.trim()) || /^&lt;img[^&]+&gt;/i.test(line.trim()) || /^%3Cimg[^%]+%3E/i.test(line.trim())) {
        let imgLine = line.trim();
        while (!imgLine.includes('>') && !imgLine.includes('%3E') && i + 1 < lines.length) {
          i++;
          imgLine += ' ' + lines[i].trim();
        }
        elements.push(renderImgTag(imgLine, `img-line-${i}`, isDark));
      } else if (/<video[^>]*>[\s\S]*?<\/video>|<video[^>]+>/i.test(line.trim())) {
        elements.push(renderVideoTag(line.trim(), `vid-line-${i}`));
      } else {
        const inlineParts = extractHtmlTags(line);
        if (inlineParts && inlineParts.length > 0) {
          // 有 img/video 标签：提取 HTML 标签渲染，剩余文本正常显示
          elements.push(
            <View key={`p-${i}`} style={{ marginBottom: Spacing.xs }}>
              {inlineParts.map((part, pIdx) => {
                if (typeof part === 'string') {
                  return <Text key={`pt-${pIdx}`} style={[styles.paragraph, { color: textColor }]}>{renderInline(part, `ip-${i}-${pIdx}`)}</Text>;
                }
                return <React.Fragment key={`pv-${pIdx}`}>{part}</React.Fragment>;
              })}
            </View>
          );
        } else {
          // [FIX] 普通文本段落：文字用 renderInlineForParagraph（文件/视频链接只显示蓝色文字）
          // 文件卡片和视频播放器单独提取渲染在段落下方
          const fileLinkRe = /\[([^\]]+)\]\(([^)]+)\)/g;
          const fileCards: { label: string; url: string }[] = [];
          const videoCards: { label: string; url: string }[] = [];
          let fm;
          let fmIdx = 0;
          const tempRe = /\[([^\]]+)\]\(([^)]+)\)/g;
          while ((fm = tempRe.exec(line)) !== null) {
            if (/\.(mp4|webm|mov|m3u8)(\?|$)/i.test(fm[2])) {
              videoCards.push({ label: fm[1], url: fm[2] });
            } else if (pickFileInfo(fm[2])) {
              fileCards.push({ label: fm[1], url: fm[2] });
            }
          }
          elements.push(
            <View key={`p-${i}`} style={{ marginBottom: Spacing.xs }}>
              <Text selectable style={[styles.paragraph, { color: textColor }]}>{renderInlineForParagraph(line, `p-${i}`)}</Text>
              {videoCards.map((vc, vcIdx) => (
                <View key={`vc-${i}-${vcIdx}`} style={{ marginTop: 6 }}><VideoPlayerInline src={vc.url} videoKey={`vc-${i}-${vcIdx}`} /></View>
              ))}
              {fileCards.map((fc, fcIdx) => (
                <View key={`fc-${i}-${fcIdx}`} style={{ marginTop: 6 }}><FileDownloadCard url={fc.url} /></View>
              ))}
            </View>
          );
        }
      }
    }
  }

  // Fallback: if no elements rendered but content exists, show raw text
  const fallbackText = (elements.length === 0 && trimmedContent.length > 0)
    ? <Text key="fallback" selectable style={[styles.paragraph, { color: textColor }]}>{trimmedContent}</Text>
    : null;

  return (
    <>
      {Platform.OS === 'web' && <style>{webWrapCSS}</style>}
      <View
      style={styles.container}
      className="md-bubble"
    >{elements.length > 0 ? elements : fallbackText}</View>
    {mdPreviewUrl ? <MarkdownPreviewModal url={mdPreviewUrl} onClose={() => setMdPreviewUrl(null)} /> : null}
    </>
  );
};

const styles = StyleSheet.create({
  container: { paddingVertical: Spacing.xs, flexShrink: 1, flexGrow: 0, width: '100%', minWidth: 0, maxWidth: '100%' },
  imgContainer: { marginVertical: Spacing.sm, borderRadius: BorderRadius.md, overflow: 'hidden' },
  img: { width: '100%', height: 220, borderRadius: BorderRadius.md, backgroundColor: '#f0f0f0' },
  videoContainer: { marginVertical: Spacing.sm, borderRadius: BorderRadius.md, overflow: 'hidden', backgroundColor: '#000' },
  videoPlayer: { width: '100%', height: 220, borderRadius: BorderRadius.md },
  videoLink: { flexDirection: 'row', alignItems: 'center', paddingVertical: Spacing.sm, paddingHorizontal: Spacing.md, backgroundColor: '#1e293b', borderRadius: BorderRadius.md, marginVertical: Spacing.sm },
  videoLinkText: { color: '#60a5fa', fontSize: FontSize.sm, marginLeft: Spacing.xs },
  h1: { fontSize: FontSize.xxl, fontWeight: '700', marginBottom: Spacing.sm },
  h2: { fontSize: FontSize.xl, fontWeight: '700', marginBottom: Spacing.sm },
  h3: { fontSize: FontSize.lg, fontWeight: '600', marginBottom: Spacing.xs },
  paragraph: { fontSize: FontSize.md, lineHeight: FontSize.md * 1.4, marginBottom: 2 },
  codeBlock: { borderRadius: BorderRadius.md, padding: Spacing.md, marginVertical: Spacing.sm },
  codeLang: { fontSize: FontSize.xs, marginBottom: Spacing.xs, fontFamily: 'monospace' },
  codeText: { fontSize: FontSize.sm, fontFamily: 'monospace', lineHeight: FontSize.sm * 1.5 },
  inlineCode: { paddingHorizontal: Spacing.xs, paddingVertical: 2, borderRadius: BorderRadius.sm, fontSize: FontSize.sm * 0.9, fontFamily: 'monospace' },
  quote: { borderLeftWidth: 3, paddingLeft: Spacing.md, marginVertical: Spacing.xs },
  quoteText: { fontSize: FontSize.md, fontStyle: 'italic' },
  listItem: { flexDirection: 'row', alignItems: 'flex-start', marginBottom: Spacing.xs },
});
