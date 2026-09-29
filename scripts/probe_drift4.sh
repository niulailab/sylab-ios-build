#!/bin/bash
echo "=== ACTIVE tasks (all users) ==="
docker exec coze-mysql mysql -uroot -pd3G8JG273iE8C4irRWJX opencoze --default-character-set=utf8mb4 -e "SELECT id,task_uuid,user_id,conversation_id,bot_id,status,schedule_type,schedule_expr,next_run_at,last_run_at,last_status,run_count FROM sylab_scheduled_tasks WHERE status='active' \G" 2>/dev/null
echo
echo "=== trigger execute code 4690-4865 ==="
sed -n '4690,4865p' /root/coze-studio/tool-proxy/server.py
echo "[DONE]"
