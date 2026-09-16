import { toRuntimeUrl } from '../config/runtime';
import { Linking, Platform, Share, Alert } from 'react-native';
import * as FileSystem from 'expo-file-system';

// 把自建 http 地址统一换成 https 隧道，规避 iOS ATS
export function normalizeServerUrl(url: string): string {
  if (!url) return url;
  return toRuntimeUrl(url);
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

// 非 ASCII（中文文件名等）做百分号编码；已编码的 %XX 不会被二次编码（encodeURI 保留 %）
function safeEncodeUrl(u: string): string {
  try {
    return /[^\x00-\x7F]/.test(u) ? encodeURI(u) : u;
  } catch {
    return u;
  }
}

// 兜底下载：主下载器（NSURLSession）对外域 CDN 偶发失败时，用 fetch（与图片/视频同一网络栈）
// 拉取后以 base64 写入缓存。适合几十 MB 以内的文件（海螺视频通常 1~5MB）。
async function fetchDownloadFallback(url: string, target: string): Promise<string> {
  const resp = await fetch(url);
  if (!resp.ok) throw new Error('HTTP ' + resp.status);
  const blob: any = await resp.blob();
  const base64: string = await new Promise((resolve, reject) => {
    const fr = new FileReader();
    fr.onload = () => resolve(String(fr.result).split(',')[1] || '');
    fr.onerror = () => reject(new Error('read error'));
    fr.readAsDataURL(blob);
  });
  await FileSystem.writeAsStringAsync(target, base64, { encoding: FileSystem.EncodingType.Base64 });
  return target;
}

// 文件/视频/图片：App 内闭环下载，绝不跳外部浏览器。
// 流程：下载到 App 缓存目录（带进度）→ expo-sharing 系统分享面板（iOS 可"存储到文件/视频"，
// 全程停留在 App 上下文，不打开 Safari）；expo-sharing 不可用时兜底 React Native Share。
// onProgress: 0~1 下载进度回调（可选）。
export async function downloadAndShare(
  rawUrl: string,
  onProgress?: (ratio: number) => void
): Promise<void> {
  const url = normalizeServerUrl(rawUrl);
  if (Platform.OS === 'web') {
    try { window.open(url, '_blank'); } catch {}
    return;
  }
  // iOS / Android 统一：App 内下载 + 系统分享面板（不跳浏览器）
  const { name, info } = fileMeta(url);
  const safeName = (name || 'file').replace(/[\\/:*?"<>|]+/g, '_');
  const target = FileSystem.cacheDirectory + 'dl_' + Date.now() + '_' + safeName;
  const encUrl = safeEncodeUrl(url);
  let uri = '';
  try {
    let lastEmit = 0;
    const downloadResumable = FileSystem.createDownloadResumable(
      encUrl,
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
    let result: any;
    try {
      result = await downloadResumable.downloadAsync();
      uri = result?.uri || target;
    } catch (primaryErr: any) {
      // 主下载器对外域 CDN 偶发失败 → fetch 兜底（与播放器/图片同一网络栈）
      console.warn('[fileOpen] primary download failed, try fetch fallback:', primaryErr?.message || primaryErr);
      try {
        uri = await fetchDownloadFallback(encUrl, target);
      } catch (fbErr: any) {
        throw new Error((primaryErr?.message || 'download error') + ' / fallback: ' + (fbErr?.message || fbErr));
      }
    }
    if (!uri) uri = target;
    // 校验文件确实落盘且非空
    try {
      const info2 = await FileSystem.getInfoAsync(uri, { size: true });
      if (!info2.exists || !(info2 as any).size) throw new Error('empty file');
    } catch (ve) { throw new Error('downloaded file invalid: ' + (ve as any)?.message); }
    onProgress?.(1);
    try {
      let handled = false;
      try {
        const Sharing = require('expo-sharing');
        if (await Sharing.isAvailableAsync()) {
          // iOS UTI / Android mimeType 都传上，分享面板可正确识别"存储到文件/视频"
          await Sharing.shareAsync(uri, {
            mimeType: info.mime,
            UTI: info.uti,
            dialogTitle: safeName,
          } as any);
          handled = true;
        }
      } catch (se) { console.warn('[fileOpen] expo-sharing unavailable:', se); }
      if (!handled) {
        await Share.share({ url: uri, filename: safeName, title: safeName } as any);
      }
    } catch (se: any) {
      // 用户主动关闭分享面板不算错误
      if (se && /dismiss|cancel/i.test(String(se.message || ''))) return;
    }
  } catch (e: any) {
    const msg = e?.message || String(e);
    console.warn('[fileOpen] download/share failed:', msg);
    Alert.alert('下载失败', '文件下载失败，请重试。\n(' + String(msg).slice(0, 120) + ')');
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
    const target = FileSystem.cacheDirectory + 'preview_' + Date.now() + '_' + safeName;
    try {
      const { uri } = await FileSystem.downloadAsync(safeEncodeUrl(url), target);
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
