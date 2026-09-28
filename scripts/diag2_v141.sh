#!/bin/bash
SK=$(docker exec coze-mysql mysql --default-character-set=utf8mb4 -uroot -pd3G8JG273iE8C4irRWJX opencoze -N -e \
 "SELECT session_key FROM user WHERE id='7666848996043784192';" 2>/dev/null)
echo "sk len=${#SK}"

echo "=== user table has deleted_at? ==="
docker exec coze-mysql mysql -uroot -pd3G8JG273iE8C4irRWJX opencoze -N -e \
 "SELECT COLUMN_NAME FROM information_schema.COLUMNS WHERE TABLE_SCHEMA='opencoze' AND TABLE_NAME='user' AND COLUMN_NAME IN ('deleted_at','session_key','id');" 2>/dev/null

echo "=== run exact backend lookup SQL ==="
docker exec coze-mysql mysql --default-character-set=utf8mb4 -uroot -pd3G8JG273iE8C4irRWJX opencoze -e \
 "SELECT id FROM user WHERE session_key='$(echo "$SK" | sed "s/'/''/g")' AND deleted_at IS NULL LIMIT 1;" 2>&1 | grep -v "Using a password"

echo "=== DIRECT to 9092 with header ==="
curl -s -X POST http://127.0.0.1:9092/schedule/list -H 'Content-Type: application/json' \
 -H "x-session-key: $SK" -d '{"scope":"all"}'; echo ""

echo "=== via 9091 with header ==="
curl -s -X POST http://127.0.0.1:9091/schedule/list -H 'Content-Type: application/json' \
 -H "x-session-key: $SK" -d '{"scope":"all"}'; echo ""

echo "=== backend logs last 15 ==="
docker logs tool-proxy --since 2m 2>&1 | grep -iE "SCHED-DBG|identity|resolve|error|traceback" | tail -15
