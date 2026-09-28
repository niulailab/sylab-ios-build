#!/bin/bash
echo "=== all running containers ==="
docker ps --format '{{.Names}}\t{{.Status}}\t{{.Ports}}'
echo ""
echo "=== raw no-cred list body ==="
curl -s -X POST http://127.0.0.1:9091/schedule/list -H 'Content-Type: application/json' -d '{"scope":"all"}'
echo ""
echo "=== check tables exist ==="
docker exec coze-mysql mysql -uroot -pd3G8JG273iE8C4irRWJX opencoze -N -e "SHOW TABLES LIKE 'sylab_sched%';" 2>&1 | grep -v "Using a password"
echo "=== count (show errors) ==="
docker exec coze-mysql mysql -uroot -pd3G8JG273iE8C4irRWJX opencoze -e "SELECT COUNT(*) AS n FROM sylab_scheduled_tasks;" 2>&1 | grep -v "Using a password"
echo "=== active rows all incl deleted ==="
docker exec coze-mysql mysql -uroot -pd3G8JG273iE8C4irRWJX opencoze -e "SELECT id,uuid,title,status,deleted_at FROM sylab_scheduled_tasks;" 2>&1 | grep -v "Using a password"
