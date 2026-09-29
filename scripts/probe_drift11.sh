#!/bin/bash
echo "=== the trigger user msg row (full) ==="
docker exec coze-mysql mysql -uroot -pd3G8JG273iE8C4irRWJX opencoze --default-character-set=utf8mb4 -e "SELECT id,run_id,conversation_id,user_id,agent_id,role,message_type,LEFT(content,70) c,created_at FROM message WHERE id='7690748074301325312' \G" 2>/dev/null
echo
echo "=== expected conv 7687609248154386432: does it exist & its recent msgs ==="
docker exec coze-mysql mysql -uroot -pd3G8JG273iE8C4irRWJX opencoze --default-character-set=utf8mb4 -e "SELECT COUNT(*) total, MAX(created_at) last FROM message WHERE conversation_id='7687609248154386432';" 2>/dev/null
docker exec coze-mysql mysql -uroot -pd3G8JG273iE8C4irRWJX opencoze --default-character-set=utf8mb4 -e "SELECT id,role,LEFT(content,55) c,created_at FROM message WHERE conversation_id='7687609248154386432' ORDER BY id DESC LIMIT 8;" 2>/dev/null
echo
echo "=== conversation table cols & row for actual conv 7690748074301325312 ==="
docker exec coze-mysql mysql -uroot -pd3G8JG273iE8C4irRWJX opencoze -N -e "SHOW COLUMNS FROM conversation;" 2>/dev/null | awk '{print $1}'
echo "---"
docker exec coze-mysql mysql -uroot -pd3G8JG273iE8C4irRWJX opencoze --default-character-set=utf8mb4 -e "SELECT * FROM conversation WHERE id='7690748074301325312' \G" 2>/dev/null | head -30
echo "[DONE]"
