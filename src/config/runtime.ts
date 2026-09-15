// 运行时出口：web 走 Cloudflare 域名；原生(iOS/Android)直连国内源站 8099，绕过被干扰的 CF 链路
import { Platform } from 'react-native';

export const RUNTIME_BASE = Platform.OS === 'web'
  ? 'https://s.symsgf.xyz'
  : 'https://direct.symsgf.xyz:8099';

// 把任意服务端/隧道地址归一化到当前平台真正可达的出口
export function toRuntimeUrl(url: string): string {
  if (!url) return url;
  return String(url)
    .replace(/https?:\/\/s\.symsgf\.xyz(?::\d+)?/g, RUNTIME_BASE)
    .replace(/http:\/\/36\.137\.84\.216:9091/g, RUNTIME_BASE)
    .replace(/http:\/\/127\.0\.0\.1:9091/g, RUNTIME_BASE)
    .replace(/http:\/\/localhost:9091/g, RUNTIME_BASE);
}
