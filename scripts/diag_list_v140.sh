#!/bin/bash
echo "=== active tasks: owner user_id ==="
docker exec coze-mysql mysql --default-character-set=utf8mb4 -uroot -pd3G8JG273iE8C4irRWJX opencoze -N -e \
 "SELECT task_uuid,user_id,conversation_id,title,status FROM sylab_scheduled_tasks WHERE status='active';" 2>/dev/null | base64
echo ""
echo "=== who are those users ==="
docker exec coze-mysql mysql --default-character-set=utf8mb4 -uroot -pd3G8JG273iE8C4irRWJX opencoze -e \
 "SELECT id,name,email, LEFT(session_key,12) AS sk_head FROM user WHERE id IN (SELECT DISTINCT user_id FROM sylab_scheduled_tasks WHERE status='active');" 2>&1 | grep -v "Using a password"
echo ""
echo "=== tool-proxy recent schedule list log lines ==="
docker logs tool-proxy --since 30m 2>&1 | grep -iE "schedule|identity|resolve|list" | tail -25
