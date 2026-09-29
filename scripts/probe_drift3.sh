#!/bin/bash
echo "=== all rows (no deleted_at) ==="
docker exec coze-mysql mysql -uroot -pd3G8JG273iE8C4irRWJX opencoze --default-character-set=utf8mb4 -e "SELECT id,task_uuid,user_id,conversation_id,bot_id,title,status,schedule_type,schedule_expr,next_run_at,last_run_at,last_status,run_count FROM sylab_scheduled_tasks ORDER BY id DESC LIMIT 15 \G" 2>/dev/null
echo
echo "=== scheduler tick in tool-proxy server.py ==="
grep -nE "sylab_scheduled_tasks|FROM sylab_sched|next_run_at <=|def .*tick|def .*due|def .*run_due|scheduler_tick|/schedule/tick|internal/sched" /root/coze-studio/tool-proxy/server.py | head -30
echo "[DONE]"
