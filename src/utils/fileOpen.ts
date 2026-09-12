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

// 普通网页链接：才跳外部浏览器
export function openExternally(url: string) {
  return Linking.openURL(normalizeServerUrl(url)).catch(() => {});
}

// 文件/图片：App 内下载后直接弹系统分享/保存面板，不跳浏览器。
// 使用 RN 内置 Share（iOS 换壳基线无 expo-sharing 原生模块，require 会致命崩溃）。
export async function downloadAndShare(rawUrl: string): Promise<void> {
  const url = normalizeServerUrl(rawUrl);
  if (Platform.OS === 'web') {
    try { window.open(url, '_blank'); } catch {}
    return;
  }
  const { name, info } = fileMeta(url);
  const safeName = (name || 'file').replace(/[\\/:*?"<>|]+/g, '_');
  const target = FileSystem.cacheDirectory + safeName;
  try {
    const { uri } = await FileSystem.downloadAsync(url, target);
    try {
      if (Platform.OS === 'ios') {
        await Share.share({ url: uri, filename: safeName } as any);
      } else {
        // Android：优先用基线已有的 expo-sharing（全量 APK 含该原生模块）
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
      }
    } catch (se: any) {
      // 用户取消分享会抛错，属正常，不提示
      if (se && /dismiss|cancel/i.test(String(se.message || ''))) return;
    }
  } catch (e: any) {
    const msg = e?.message || String(e);
    console.warn('[fileOpen] download/share failed:', msg);
    Alert.alert('下载失败', '文件下载失败，请检查网络后重试。');
  }
}
