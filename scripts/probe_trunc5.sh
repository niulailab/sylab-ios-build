#!/bin/bash
echo "=== 1) 带时间戳的 docker logs 看 network_error 精确时间 ==="
docker logs --since "2026-09-29T09:30:00" --until "2026-09-29T10:10:00" tool-proxy 2>&1 | grep -B1 "network_error"
echo
echo "=== 2) 找 conv 7690537547025350656 在 tool-proxy 的 POST /bigmodel 时间线 ==="
docker logs --since "2026-09-29T09:30:00" tool-proxy 2>&1 | grep -E "POST /bigmodel|network_error" | head -40
echo
echo "=== 3) 该 conv 的消息时间线（assistant 纯文本的） ==="
docker exec coze-mysql mysql -uroot -pd3G8JG273iE8C4irRWJX opencoze --default-character-set=utf8mb4 -e "SELECT id, LEFT(content,50) c, created_at FROM message WHERE conversation_id='7690537547025350656' AND role='assistant' AND content NOT LIKE '{%' AND created_at>='2026-09-29 09:20:00' ORDER BY id DESC LIMIT 10;" 2>/dev/null
echo
echo "=== 4) zhipu-proxy 的 network_error 处理分支在哪 ==="
grep -nE "network_error|except.*ReadTimeout|except.*RemoteProtocol|except.*httpx|NetworkError|StreamError" /root/coze-studio/tool-proxy/server.py | head
echo "[DONE]"
