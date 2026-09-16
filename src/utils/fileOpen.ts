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

// 文件大小：优先 HEAD；HEAD 不被支持（501/405）时用 GET Range 取首字节读 Content-Range/Content-Length
export async function fetchFileSize(rawUrl: string): Promise<number | null> {
  const url = normalizeServerUrl(rawUrl);
  if (Platform.OS === 'web') return null;
  const parseLen = (res: Response): number | null => {
    const cr = res.headers.get('Content-Range') || res.headers.get('content-range');
    if (cr && cr.includes('/')) {
      const total = cr.split('/').pop() || '';
      const n = parseInt(total, 10);
      if (!isNaN(n) && n > 0) return n;
    }
    const len = res.headers.get('Content-Length') || res.headers.get('content-length');
    if (len) { const n = parseInt(len, 10); if (!isNaN(n) && n > 0) return n; }
    return null;
  };
  try {
    const head = await fetch(url, { method: 'HEAD' });
    const n = parseLen(head);
    if (n) return n;
  } catch {}
  try {
    const get = await fetch(url, { headers: { Range: 'bytes=0-0' } });
    const n = parseLen(get);
    if (n) return n;
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

// ---- 二进制落盘（09-13 真机验证过的唯一稳定路径）----
// 关键：在免证书原生包里，FileSystem.downloadAsync / createDownloadResumable 保存二进制会异常，
// 必须 fetch/XHR 拿到 ArrayBuffer → 分块 base64 → writeAsStringAsync(Base64) 落盘。
function arrayBufferToBase64(buf: ArrayBuffer): string {
  const bytes = new Uint8Array(buf);
  let binary = '';
  const chunk = 0x8000; // 32KB，避免 String.fromCharCode.apply 参数过多
  for (let i = 0; i < bytes.length; i += chunk) {
    const slice = bytes.subarray(i, Math.min(i + chunk, bytes.length));
    let part = '';
    for (let j = 0; j < slice.length; j++) part += String.fromCharCode(slice[j]);
    binary += part;
  }
  return btoa(binary);
}

function xhrDownload(url: string, onProgress?: (ratio: number) => void): Promise<ArrayBuffer> {
  return new Promise((resolve, reject) => {
    const x = new XMLHttpRequest();
    x.open('GET', url, true);
    x.responseType = 'arraybuffer';
    x.timeout = 180000;
    let lastEmit = 0;
    x.onprogress = (e: any) => {
      if (!onProgress || !e.lengthComputable) return;
      const ratio = Math.max(0, Math.min(1, e.loaded / e.total));
      const now = Date.now();
      if (ratio - lastEmit > 0.03 || now - lastEmit > 200 || ratio >= 1) { lastEmit = ratio; onProgress(ratio); }
    };
    x.onload = () => {
      if (x.status >= 200 && x.status < 300) resolve(x.response as ArrayBuffer);
      else reject(new Error('HTTP ' + x.status));
    };
    x.onerror = () => reject(new Error('网络请求失败'));
    x.ontimeout = () => reject(new Error('下载超时'));
    x.send();
  });
}

// 下载到缓存并返回本地 file:// uri（预览/下载共用，已验证稳定）
async function downloadBinaryToCache(
  rawUrl: string,
  prefix: string,
  onProgress?: (ratio: number) => void
): Promise<{ uri: string; safeName: string; mime: string; uti: string }> {
  const url = normalizeServerUrl(rawUrl);
  const { name, info } = fileMeta(url);
  const safeName = (name || 'file').replace(/[\\/:*?"<>|]+/g, '_');
  const target = FileSystem.cacheDirectory + prefix + Date.now() + '_' + safeName;
  try { await FileSystem.deleteAsync(target, { idempotent: true }); } catch {}
  const encUrl = safeEncodeUrl(url);
  const buf = await xhrDownload(encUrl, onProgress);
  if (!buf || buf.byteLength === 0) throw new Error('empty body');
  const b64 = arrayBufferToBase64(buf);
  await FileSystem.writeAsStringAsync(target, b64, { encoding: FileSystem.EncodingType.Base64 });
  const st = await FileSystem.getInfoAsync(target, { size: true });
  if (!st.exists || !(st as any).size) throw new Error('file not written');
  onProgress?.(1);
  return { uri: target, safeName, mime: info.mime, uti: info.uti };
}

// 文件/视频/图片：App 内闭环下载，绝不跳外部浏览器。
// 下载到 App 缓存 → expo-sharing 系统分享面板（iOS 可"存储到文件/视频"，全程不离开 App）。
export async function downloadAndShare(
  rawUrl: string,
  onProgress?: (ratio: number) => void
): Promise<void> {
  if (Platform.OS === 'web') {
    try { window.open(normalizeServerUrl(rawUrl), '_blank'); } catch {}
    return;
  }
  try {
    const { uri, safeName, mime, uti } = await downloadBinaryToCache(rawUrl, 'dl_', onProgress);
    try {
      let handled = false;
      try {
        const Sharing = require('expo-sharing');
        if (await Sharing.isAvailableAsync()) {
          await Sharing.shareAsync(uri, { mimeType: mime, UTI: uti, dialogTitle: safeName } as any);
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
// react-native-file-viewer 原生模块存在（原生编译包）时，下载到缓存后用系统预览器原地打开，不弹分享、不跳浏览器。
let _nativeViewer: { open: (path: string) => Promise<void> } | null | undefined;
function tryGetNativeViewer() {
  if (_nativeViewer !== undefined) return _nativeViewer;
  try {
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
  if (Platform.OS === 'web') { openExternally(rawUrl); return; }
  const viewer = tryGetNativeViewer();
  if (viewer) {
    try {
      const { uri } = await downloadBinaryToCache(rawUrl, 'preview_');
      await viewer.open(uri);
      return;
    } catch (e: any) {
      if (e && /dismiss|cancel/i.test(String(e.message || ''))) return;
      console.warn('[fileOpen] native preview failed, fallback share:', e?.message);
    }
  }
  // 无原生预览模块时兜底：下载 + 系统分享/打开面板
  await downloadAndShare(rawUrl);
}
