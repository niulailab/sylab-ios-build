#!/bin/bash
echo "=== tool-proxy health ==="
docker ps --format '{{.Names}}\t{{.Status}}' | grep -E "tool-proxy|chat-queue|coze-mysql|coze-server"
echo ""
echo "=== schedule list via 9091 (no cred -> should reject) ==="
curl -s -X POST http://127.0.0.1:9091/schedule/list -H 'Content-Type: application/json' -d '{"scope":"all"}' -o /dev/null -w "no-cred http=%{http_code}\n"
echo ""
echo "=== backend live tasks in DB ==="
docker exec coze-mysql mysql -uroot -pd3G8JG273iE8C4irRWJX opencoze -N -e \
 "SELECT uuid,title,status,run_count,last_status FROM sylab_scheduled_tasks WHERE deleted_at IS NULL;" 2>/dev/null
echo ""
echo "=== recent schedule_runs ==="
docker exec coze-mysql mysql -uroot -pd3G8JG273iE8C4irRWJX opencoze -N -e \
 "SELECT task_uuid,status,created_at FROM sylab_schedule_runs ORDER BY id DESC LIMIT 5;" 2>/dev/null
echo ""
echo "=== existing main routes still present in nginx ==="
grep -cE "location" /etc/nginx/sites-enabled/default
nginx -t 2>&1 | tail -2
echo "[DONE]"
