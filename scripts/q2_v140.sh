#!/bin/bash
echo "=== non-deleted tasks ==="
docker exec coze-mysql mysql -uroot -pd3G8JG273iE8C4irRWJX opencoze -e \
 "SELECT task_uuid,title,status,run_count,last_status,next_run_at FROM sylab_scheduled_tasks WHERE status!='deleted';" 2>&1 | grep -v "Using a password"
echo ""
echo "=== status breakdown ==="
docker exec coze-mysql mysql -uroot -pd3G8JG273iE8C4irRWJX opencoze -e \
 "SELECT status,COUNT(*) FROM sylab_scheduled_tasks GROUP BY status;" 2>&1 | grep -v "Using a password"
echo ""
echo "=== runs columns ==="
docker exec coze-mysql mysql -uroot -pd3G8JG273iE8C4irRWJX opencoze -e "DESC sylab_schedule_runs;" 2>&1 | grep -v "Using a password" | awk '{print $1}'
