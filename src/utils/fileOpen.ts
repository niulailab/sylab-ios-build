import { Linking, Platform, Share, Alert } from 'react-native';
import * as FileSystem from 'expo-file-system';

// 把自建 http 地址统一换成 https 隧道，规避 iOS ATS
export function normalizeServerUrl(url: string): string {
  if (!url) return url;
  return url
    .replace(/http:\/\/36\.137\.84\.216:9091/g, 'https://s.symsgf.xyz')
    .replace(/http:\/\/127\.0\.0\.1:9091/g, 'https://s.symsgf.xyz')
    .replace(/http:\/\/localhost:9091/g, 'https://s.symsgf.xyz');
}

const MIME_MAP: { [k: string]: { mime: string; uti: string } } = {
  '.pptx': { mime: 'application/vnd.openxmlformats-officedocument.presentationml.presentation', uti: 'org.openxmlformats.presentationml.presentation' },
  '.ppt':  { mime: 'application/vnd.ms-powerpoint', uti: 'com.microsoft.powerpoint.ppt' },
  '.docx': { mime: 'application/vnd.openxmlformats-officedocument.wordprocessingml.document', uti: 'org.openxmlformats.wordprocessingml.document' },
  '.doc':  { mime: 'application/msword', uti: 'com.microsoft.word.doc' },
  '.xlsx': { mime: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet', uti: 'org.openxmlformats.spreadsheetml.sheet' },
  '.xls':  { mime: 'application/vnd.ms-excel', uti: 'com.microsoft.excel.xls' },
  '.csv':  { mime: 'text/csv', uti: 'public.comma-separated-values-text' },
  '.pdf':  { mime: 'application/pdf', uti: 'com.adobe.pdf' },
  '.zip':  { mime: 'application/zip', uti: 'public.zip-archive' },
  '.txt':  { mime: 'text/plain', uti: 'public.plain-text' },
  '.md':   { mime: 'text/markdown', uti: 'net.daringfireball.markdown' },
  '.png':  { mime: 'image/png', uti: 'public.png' },
  '.jpg':  { mime: 'image/jpeg', uti: 'public.jpeg' },
  '.jpeg': { mime: 'image/jpeg', uti: 'public.jpeg' },
  '.gif':  { mime: 'image/gif', uti: 'com.compuserve.gif' },
  '.webp': { mime: 'image/webp', uti: 'org.webmproject.webp' },
  '.mp4':  { mime: 'video/mp4', uti: 'public.mpeg-4' },
  '.mov':  { mime: 'video/quicktime', uti: 'com.apple.quicktime-movie' },
};

function fileMeta(url: string) {
  const clean = (url.split('?')[0] || '').toLowerCase();
  const dot = clean.lastIndexOf('.');
  const ext = dot >= 0 ? clean.slice(dot) : '';
  const base = (url.split('?')[0].split('/').pop() || ('file' + ext));
  let name = base;
  try { name = decodeURIComponent(base); } catch {}
  return { ext, name, info: (MIME_MAP[ext] || { mime: 'application/octet-stream', uti: 'public.data' }) };
}

export function formatFileSize(bytes?: number | null): string {
  if (bytes == null || isNaN(bytes) || bytes < 0) return '';
  if (bytes < 1024) return bytes + ' B';
  if (bytes < 1024 * 1024) return (bytes / 1024).toFixed(1).replace(/\.0$/, '') + ' KB';
  if (bytes < 1024 * 1024 * 1024) return (bytes / (1024 * 1024)).toFixed(1).replace(/\.0$/, '') + ' MB';
  return (bytes / (1024 * 1024 * 1024)).toFixed(2) + ' GB';
}

// HEAD 请求拿文件大小（nginx 支持 content-length）；失败静默返回 null，不阻塞 UI
export async function fetchFileSize(rawUrl: string): Promise<number | null> {
  const url = normalizeServerUrl(rawUrl);
  if (Platform.OS === 'web') return null;
  try {
    const res = await fetch(url, { method: 'HEAD' });
    const len = res.headers.get('Content-Length') || res.headers.get('content-length');
    if (len) {
      const n = parseInt(len, 10);
      if (!isNaN(n) && n > 0) return n;
    }
  } catch {}
  return null;
}

// 普通网页链接：才跳外部浏览器
export function openExternally(url: string) {
  return Linking.openURL(normalizeServerUrl(url)).catch(() => {});
}

// 文件/图片：iOS 换壳环境直接跳 Safari 下载（最稳，避免 Share 模块和文件系统权限问题）
// Android 用 Share 面板。
// onProgress: 0~1 下载进度回调（可选，iOS 跳浏览器时不触发）。
export async function downloadAndShare(
  rawUrl: string,
  onProgress?: (ratio: number) => void
): Promise<void> {
  const url = normalizeServerUrl(rawUrl);
  if (Platform.OS === 'web') {
    try { window.open(url, '_blank'); } catch {}
    return;
  }
  // iOS 换壳：直接跳 Safari 下载，系统自动处理文件预览/存储
  if (Platform.OS === 'ios') {
    try {
      const canOpen = await Linking.canOpenURL(url);
      if (canOpen) {
        await Linking.openURL(url);
      } else {
        // Safari 无法打开，尝试 Share 兜底
        const { name, info } = fileMeta(url);
        const safeName = (name || 'file').replace(/[\\/:*?"<>|]+/g, '_');
        const target = FileSystem.cacheDirectory + safeName;
        const downloadResumable = FileSystem.createDownloadResumable(url, target, {}, onProgress ? (dp) => {
          const total = dp.totalBytesExpectedToWrite || 0;
          const ratio = total > 0 ? Math.min(1, dp.totalBytesWritten / total) : 0;
          onProgress(ratio);
        } : undefined);
        const result = await downloadResumable.downloadAsync();
        const uri = (result as any)?.uri || target;
        await Share.share({ url: uri, filename: safeName } as any);
      }
    } catch (e: any) {
      const msg = e?.message || String(e);
      console.warn('[fileOpen] iOS download failed:', msg);
      Alert.alert('下载失败', '文件下载失败，请检查网络后重试。');
    }
    return;
  }
  // Android
  const { name, info } = fileMeta(url);
  const safeName = (name || 'file').replace(/[\\/:*?"<>|]+/g, '_');
  const target = FileSystem.cacheDirectory + safeName;
  try {
    let lastEmit = 0;
    const downloadResumable = FileSystem.createDownloadResumable(
      url,
      target,
      {},
      (dp) => {
        if (!onProgress) return;
        const total = dp.totalBytesExpectedToWrite || 0;
        const ratio = total > 0 ? Math.min(1, dp.totalBytesWritten / total) : 0;
        const now = Date.now();
        if (ratio - lastEmit > 0.03 || now - lastEmit > 200 || ratio >= 1) {
          lastEmit = ratio;
          onProgress(ratio);
        }
      }
    );
    const result = await downloadResumable.downloadAsync();
    const uri = (result as any)?.uri || target;
    onProgress?.(1);
    try {
      let handled = false;
      try {
        const Sharing = require('expo-sharing');
        if (await Sharing.isAvailableAsync()) {
          await Sharing.shareAsync(uri, { mimeType: info.mime, dialogTitle: safeName });
          handled = true;
        }
      } catch (se) { console.warn('[fileOpen] expo-sharing unavailable:', se); }
      if (!handled) {
        await Share.share({ url: 'file://' + uri, title: safeName } as any);
      }
    } catch (se: any) {
      if (se && /dismiss|cancel/i.test(String(se.message || ''))) return;
    }
  } catch (e: any) {
    const msg = e?.message || String(e);
    console.warn('[fileOpen] download/share failed:', msg);
    Alert.alert('下载失败', '文件下载失败，请检查网络后重试。');
  }
}

// App 内预览（QuickLook / FileProvider）。
// v105 第一批（纯 JS 换壳）：原生模块未接入前，下载后直接交给系统分享面板，
// 用户可在面板里选"存储到文件/用 WPS·Pages 打开"，功能不缺失。
// 接入 react-native-file-viewer（原生编译包）后，此函数自动切换为 App 内 QuickLook 预览。
let _nativeViewer: { open: (path: string, mime?: string) => Promise<void> } | null | undefined;
function tryGetNativeViewer() {
  if (_nativeViewer !== undefined) return _nativeViewer;
  try {
    // 原生模块存在（原生编译包）时启用；换壳包 require 失败则走分享兜底
    const RNFileViewer = require('react-native-file-viewer').default;
    _nativeViewer = {
      open: (path: string) =>
        RNFileViewer.open(path, {
          showOpenWithDialog: false,
          displayName: fileMeta(path).name,
        }),
    };
  } catch {
    _nativeViewer = null;
  }
  return _nativeViewer;
}

export async function previewFile(rawUrl: string): Promise<void> {
  const url = normalizeServerUrl(rawUrl);
  if (Platform.OS === 'web') { openExternally(url); return; }
  const viewer = tryGetNativeViewer();
  if (viewer) {
    // 原生 QuickLook 路径：下载到缓存再用系统预览器打开（不弹分享面板）
    const { name } = fileMeta(url);
    const safeName = (name || 'file').replace(/[\\/:*?"<>|]+/g, '_');
    const target = FileSystem.cacheDirectory + 'preview_' + safeName;
    try {
      const { uri } = await FileSystem.downloadAsync(url, target);
      await viewer.open(uri);
      return;
    } catch (e: any) {
      if (e && /dismiss|cancel/i.test(String(e.message || ''))) return;
      console.warn('[fileOpen] native preview failed, fallback share:', e?.message);
    }
  }
  // 兜底：下载 + 系统分享/打开面板
  await downloadAndShare(rawUrl);
}
