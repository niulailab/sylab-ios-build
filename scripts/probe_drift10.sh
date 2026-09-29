#!/bin/bash
echo "=== messages 08:25-09:15 grouped by conversation/role ==="
docker exec coze-mysql mysql -uroot -pd3G8JG273iE8C4irRWJX opencoze --default-character-set=utf8mb4 -e "SELECT conversation_id, role, COUNT(*) n, MIN(created_at) mn, MAX(created_at) mx FROM message WHERE created_at>='2026-09-29 08:25:00' AND created_at<='2026-09-29 09:15:00' GROUP BY conversation_id, role ORDER BY mn;" 2>/dev/null
echo
echo "=== assistant msgs in the EXPECTED conv 7687609248154386432 today ==="
docker exec coze-mysql mysql -uroot -pd3G8JG273iE8C4irRWJX opencoze --default-character-set=utf8mb4 -e "SELECT id,role,LEFT(content,60) c,created_at FROM message WHERE conversation_id='7687609248154386432' AND created_at>='2026-09-29 00:00:00' ORDER BY id;" 2>/dev/null
echo
echo "=== all conversations of this user (find recent active) ==="
docker exec coze-mysql mysql -uroot -pd3G8JG273iE8C4irRWJX opencoze --default-character-set=utf8mb4 -e "SELECT id,bot_id,LEFT(title,30) t,created_at,updated_at FROM conversation WHERE user_id='7666848996043784192' ORDER BY updated_at DESC LIMIT 15;" 2>/dev/null
echo "[DONE]"
