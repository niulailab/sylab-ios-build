#!/bin/bash
F=/root/chat-queue-service/server.js
echo "=== processTask 291-345 ==="
sed -n '291,345p' "$F"
echo
echo "=== /internal/fire 771-840 ==="
sed -n '771,840p' "$F"
echo
echo "=== where did 08:30 task msgs land: messages mentioning task12 uuid ==="
docker exec coze-mysql mysql -uroot -pd3G8JG273iE8C4irRWJX opencoze --default-character-set=utf8mb4 -e "SELECT id,conversation_id,role,LEFT(content,50) c,created_at FROM message WHERE created_at>='2026-09-29 08:25:00' AND created_at<='2026-09-29 09:10:00' AND user_id='7666848996043784192' ORDER BY id LIMIT 40;" 2>/dev/null
echo "[DONE]"
