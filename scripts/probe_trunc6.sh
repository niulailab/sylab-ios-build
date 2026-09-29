#!/bin/bash
echo "=== 1) 09:33 之后的所有 zhipu-FINISH（看是否还有 network_error / 非 stop） ==="
docker logs --since "2026-09-29T09:33:00" tool-proxy 2>&1 | grep "zhipu-FINISH" | grep -v "reason=stop\b" | head -10
echo
echo "=== 2) 带时间戳的最后 50 行 tool-proxy 日志（看 network_error 精确到秒） ==="
docker logs --since "2026-09-29T09:30:00" --timestamps tool-proxy 2>&1 | grep -E "network_error|Started server|Waiting|startup" | head -10
echo
echo "=== 3) 09:30-10:08 该 conv 用户消息时间线 ==="
docker exec coze-mysql mysql -uroot -pd3G8JG273iE8C4irRWJX opencoze --default-character-set=utf8mb4 -e "SELECT id, LEFT(content,50) c, created_at FROM message WHERE conversation_id='7690537547025350656' AND created_at>='2026-09-29 09:30:00' ORDER BY id;" 2>/dev/null
echo
echo "=== 4) 看该 conv 用户 '你怎么又中断了' 和更晚的消息 ==="
docker exec coze-mysql mysql -uroot -pd3G8JG273iE8C4irRWJX opencoze --default-character-set=utf8mb4 -e "SELECT id, role, LEFT(content,60) c, created_at FROM message WHERE conversation_id='7690537547025350656' AND role='user' AND created_at>='2026-09-29 09:30:00' ORDER BY id;" 2>/dev/null
echo "[DONE]"
