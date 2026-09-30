#!/usr/bin/env bash
set -e
cd /root/coze-studio
echo "=== scheduled_task 表 ==="
MP=$(docker exec coze-mysql printenv MYSQL_ROOT_PASSWORD)
docker exec coze-mysql mysql -uroot -p"$MP" opencoze -e "SELECT id, title, schedule_type, next_run_time, last_run_time, run_count, status, description FROM scheduled_task WHERE status != 'deleted' ORDER BY id;" 2>&1
echo "=== scheduled_task_run 最近20条 ==="
docker exec coze-mysql mysql -uroot -p"$MP" opencoze -e "SELECT id, task_id, status, started_at, finished_at, LEFT(error_message,300) as err FROM scheduled_task_run ORDER BY id DESC LIMIT 20;" 2>&1
echo "=== scheduler-service 容器状态 ==="
docker ps -a --filter name=scheduler --no-trunc
echo "=== scheduler-service 最近150行日志 ==="
docker logs --tail 150 sylab-scheduler-service 2>&1 | tail -150
