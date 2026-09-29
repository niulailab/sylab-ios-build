#!/bin/bash
echo "=== 1) network_error 前后完整 20 行 ==="
docker logs tool-proxy --since "2026-09-29T09:30:00" 2>&1 | grep -n "" > /tmp/alltp.log
grep -n "network_error" /tmp/alltp.log
echo
echo "=== 2) network_error 发生的具体时间点前后 30 行 ==="
LINE=$(grep -n "network_error" /tmp/alltp.log | head -1 | cut -d: -f1)
if [ -n "$LINE" ]; then
  A=$((LINE-25)); [ $A -lt 1 ] && A=1
  B=$((LINE+5))
  sed -n "${A},${B}p" /tmp/alltp.log
fi
echo
echo "=== 3) 09:33 前后（我重启 tool-proxy 的时间）是否有 SSE 断流 ==="
grep -E "09:3[2-5].*|SSE|stream.*close|disconnect|cancel" /tmp/alltp.log | head -20
echo
echo "=== 4) chat-queue 错误日志最新 ==="
tail -40 /root/.pm2/logs/chat-queue-error.log 2>/dev/null
echo
echo "=== 5) chat-queue 现在到底是怎么起的 ==="
ps -ef | grep -E "node.*chat|9088" | grep -v grep
echo
echo "=== 6) 当前用户最新一条消息（sylab 中断后用户那条） ==="
docker exec coze-mysql mysql -uroot -pd3G8JG273iE8C4irRWJX opencoze --default-character-set=utf8mb4 -e "SELECT id,conversation_id,role,LEFT(content,60) c,created_at FROM message WHERE conversation_id='7690537547025350656' AND created_at>='2026-09-29 09:20:00' ORDER BY id DESC LIMIT 10;" 2>/dev/null
echo "[DONE]"
