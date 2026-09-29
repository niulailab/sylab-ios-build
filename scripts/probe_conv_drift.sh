#!/bin/bash
echo "=== scheduled_tasks table columns ==="
docker exec coze-mysql mysql -uroot -pd3G8JG273iE8C4irRWJX opencoze -N -e "SHOW COLUMNS FROM sylab_scheduled_tasks;" 2>/dev/null
echo
echo "=== tasks for user 7666848996043784192 (conv related cols) ==="
docker exec coze-mysql mysql -uroot -pd3G8JG273iE8C4irRWJX opencoze --default-character-set=utf8mb4 -e "SELECT id, uuid, user_id, conversation_id, title, status, schedule_expr, next_run_at, last_run_at FROM sylab_scheduled_tasks WHERE user_id='7666848996043784192' AND deleted_at IS NULL \G" 2>/dev/null
echo
echo "=== schedule trigger code in tool-proxy: how conversation is picked ==="
grep -nE "conversation_id|conv_id|recent|active|last_active|ORDER BY.*updated|def .*trigger|def .*run_sched|scheduled|fire|inject" /root/coze-studio/tool-proxy/server.py | grep -iE "conv|trigger|fire|schedul|active|recent" | head -40
echo "[DONE]"
