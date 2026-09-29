#!/bin/bash

echo "=== 1) 服务器到智谱的网络连通性 ==="
for i in 1 2 3; do
  curl -sS -o /dev/null -w "尝试$i: HTTP=%{http_code} DNS=%{time_namelookup}s Connect=%{time_connect}s TLS=%{time_appconnect}s TTFB=%{time_starttransfer}s Total=%{time_total}s\n" \
    -X POST "https://open.bigmodel.cn/api/paas/v4/chat/completions" \
    -H "Content-Type: application/json" \
    -d '{"model":"glm-4-flash","messages":[{"role":"user","content":"hi"}],"max_tokens":5,"stream":false}' \
    -H "Authorization: Bearer $(grep -oP 'ZHIPU_API_KEY["\s:=]+\K[A-Za-z0-9_.-]+' /root/coze-studio/tool-proxy/server.py | head -1 || echo 'dummy')" \
    --max-time 15 2>&1 || echo "尝试$i: 失败"
done

echo
echo "=== 2) DNS 解析是否正常 ==="
dig +short open.bigmodel.cn 2>/dev/null || nslookup open.bigmodel.cn 2>/dev/null | tail -5

echo
echo "=== 3) tool-proxy 中 httpx 超时配置 ==="
grep -n "timeout.*Timeout\|Timeout(" /root/coze-studio/tool-proxy/server.py | grep -v ".bak" | head -10

echo
echo "=== 4) 最近 3 小时内 zhipu-FINISH 的 reason 分布 ==="
docker logs --since "2026-09-29T07:30:00" tool-proxy 2>&1 | grep "zhipu-FINISH" | grep -oP "reason=\S+" | sort | uniq -c | sort -rn

echo
echo "=== 5) zhipu-FINISH 中 usage=None 的出现次数（network_error 特征）==="
docker logs --since "2026-09-29T07:30:00" tool-proxy 2>&1 | grep "zhipu-FINISH" | grep "usage=None" | wc -l
echo "总 FINISH 数："
docker logs --since "2026-09-29T07:30:00" tool-proxy 2>&1 | grep "zhipu-FINISH" | wc -l

echo
echo "=== 6) 智谱官方状态页/公告（最近）==="
curl -sS "https://open.bigmodel.cn" -o /dev/null -w "智谱官网状态: HTTP=%{http_code}\n" --max-time 10 2>&1

echo
echo "=== 7) 是否有限流相关 429/503 状态 ==="
docker logs --since "2026-09-29T07:30:00" tool-proxy 2>&1 | grep -iE "429|503|rate.limit|throttl|too many" | tail -10
echo "(无输出=没有限流)"

echo
echo "=== 8) 出错的 SSE 请求上下文（network_error 前后各5行）==="
docker logs --since "2026-09-29T07:30:00" tool-proxy 2>&1 | grep -B5 -A5 "reason=network_error" | head -40

echo "[DONE]"
