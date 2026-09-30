#!/usr/bin/env bash
exec > /var/www/sylab-ios/fix5_0930.txt 2>&1
set +e
MP=$(docker exec coze-mysql printenv MYSQL_ROOT_PASSWORD)
Q(){ docker exec coze-mysql mysql -uroot -p"$MP" -e "$1" opencoze 2>&1; }

echo "##### 1. 两个活跃任务当前状态"
Q "SELECT id,title,status,last_status,consecutive_failures,run_count,next_run_at,last_run_at FROM sylab_scheduled_tasks WHERE status='active';"
echo
echo "##### 2. runs 表近5条 (看结构/内容)"
Q "SELECT id,task_uuid,fired_at,result_status,LEFT(detail,80) FROM sylab_schedule_runs ORDER BY id DESC LIMIT 5;"
