// 运行时出口：统一走 Cloudflare 域名 s.symsgf.xyz
// 原因：2026-10-02 移动 DPI 对源站直连 IP(36.137.84.216)间歇性注入 RST，
// 新 TLS 连接按 SNI 被概率掐断(抓包7次中6次RST)，导致会话列表/登录时好时坏；CF 通道实测干净
import { Platform } from 'react-native';

export const RUNTIME_BASE = 'https://s.symsgf.xyz';

// 把任意服务端/隧道地址归一化到当前真正可达的出口
export function toRuntimeUrl(url: string): string {
  if (!url) return url;
  return String(url)
    .replace(/https?:\/\/direct\.symsgf\.xyz(?::\d+)?/g, RUNTIME_BASE)
    .replace(/http:\/\/36\.137\.84\.216(?::\d+)?/g, RUNTIME_BASE)
    .replace(/http:\/\/127\.0\.0\.1:9091/g, RUNTIME_BASE)
    .replace(/http:\/\/localhost:9091/g, RUNTIME_BASE);
}
