#!/bin/bash
echo "=== active tasks ==="
docker exec coze-mysql mysql -uroot -pd3G8JG273iE8C4irRWJX opencoze -e "select task_uuid,user_id,conversation_id,bot_id,title,schedule_type,schedule_expr,next_run_at,status,consecutive_failures,last_status,run_count,last_run_at from sylab_scheduled_tasks where status='active'\G" 2>/dev/null
echo "=== recent runs ==="
docker exec coze-mysql mysql -uroot -pd3G8JG273iE8C4irRWJX opencoze -e "select task_uuid,fired_at,result_status,detail from sylab_schedule_runs order by id desc limit 9\G" 2>/dev/null
