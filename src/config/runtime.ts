// 运行时出口：直连(direct.symsgf.xyz:8099) 与 Cloudflare(s.symsgf.xyz) 双通道
// 背景：
//  - 2026-10-02 移动 DPI 对源站直连 IP 间歇性 RST，曾改用 CF；
//  - 2026-10-03 国内到 CF 国际节点时好时坏，而 8099 直连真机实测稳定(约0.3s)。
// 故做双通道 + 自动健康探测：默认直连，探测失败自动切 CF，周期复检并切回。
import { Platform } from 'react-native';

export const DIRECT_BASE = 'https://direct.symsgf.xyz:8099';
export const CF_BASE = 'https://s.symsgf.xyz';

// 可变导出：import 方在“调用时”读取可拿到最新值（ES Module live binding）。
export let RUNTIME_BASE = DIRECT_BASE;

let _active = DIRECT_BASE;
function _setActive(base: string) {
  if (base === _active) return;
  _active = base;
  RUNTIME_BASE = base;
}

/** 当前生效出口（供函数式读取，如 axios 拦截器）。 */
export function getRuntimeBase(): string {
  return _active;
}

let _started = false;

async function _probe(base: string, timeoutMs = 4000): Promise<boolean> {
  const ctrl = new AbortController();
  const timer = setTimeout(() => ctrl.abort(), timeoutMs);
  try {
    const resp = await fetch(base + '/healthz?probe=1', {
      method: 'GET',
      signal: ctrl.signal,
      cache: 'no-store',
    });
    clearTimeout(timer);
    // 只要拿到 HTTP 状态码即说明与服务器连通；仅网络层失败才算不通
    return resp.status > 0;
  } catch {
    clearTimeout(timer);
    return false;
  }
}

async function _checkOnce() {
  const directOk = await _probe(DIRECT_BASE);
  if (directOk) {
    _setActive(DIRECT_BASE);
    return;
  }
  const cfOk = await _probe(CF_BASE);
  if (cfOk) {
    _setActive(CF_BASE);
  }
  // 两条都不通：保持当前选择，等下一轮
}

/** App 启动时调用一次：立即探测 + 每 20 秒周期复检。 */
export function startBaseProbe() {
  if (_started) return;
  _started = true;
  _checkOnce().catch(() => {});
  setInterval(() => {
    _checkOnce().catch(() => {});
  }, 20000);
}

/** 上报一次请求失败：立即触发复检，加快切换。 */
export function reportBaseFailure() {
  _checkOnce().catch(() => {});
}

// 把任意服务端/隧道地址归一化到当前真正可达的出口
export function toRuntimeUrl(url: string): string {
  if (!url) return url;
  const base = _active;
  return String(url)
    .replace(/https?:\/\/direct\.symsgf\.xyz(?::\d+)?/g, base)
    .replace(/https?:\/\/s\.symsgf\.xyz(?::\d+)?/g, base)
    .replace(/https?:\/\/36\.137\.84\.216(?::\d+)?/g, base)
    .replace(/http:\/\/127\.0\.0\.1:9091/g, base)
    .replace(/http:\/\/localhost:9091/g, base);
}

void Platform;
