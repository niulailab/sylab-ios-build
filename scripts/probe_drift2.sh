#!/bin/bash
echo "=== all scheduled tasks (any user, recent) ==="
docker exec coze-mysql mysql -uroot -pd3G8JG273iE8C4irRWJX opencoze --default-character-set=utf8mb4 -e "SELECT id,user_id,conversation_id,title,status,schedule_expr,next_run_at,last_run_at,last_status,run_count FROM sylab_scheduled_tasks WHERE deleted_at IS NULL ORDER BY id DESC LIMIT 15 \G" 2>/dev/null
echo
echo "=== find scheduler tick / run-due code file ==="
grep -rIln --exclude-dir=node_modules --exclude-dir=.git \
 -e "sylab_scheduled_tasks" -e "next_run_at" -e "schedule/tick" /root/coze-studio 2>/dev/null | head
echo "[DONE]"
