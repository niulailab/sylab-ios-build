#!/bin/bash
echo "=== both active tasks (utf8 via base64) ==="
docker exec coze-mysql mysql --default-character-set=utf8mb4 -uroot -pd3G8JG273iE8C4irRWJX opencoze -N -e \
 "SELECT task_uuid,title,status,run_count,last_status,next_run_at FROM sylab_scheduled_tasks WHERE status='active';" 2>/dev/null | base64
echo ""
echo "=== verify backend patch uses real columns only ==="
grep -nE "deleted_at|\.uuid|task_uuid|last_status|next_run_at|consecutive_failures|run_count" /root/coze-studio/tool-proxy/server.py | sed -n '1,40p'
