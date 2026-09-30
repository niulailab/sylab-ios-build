#!/usr/bin/env bash
set -e
echo "=== scheduled_task ==="
docker exec coze-mysql mysql -uroot -p"$(docker exec coze-mysql printenv MYSQL_ROOT_PASSWORD)" opencoze -e "SELECT id, title, schedule_type, next_run_time, last_run_time, run_count, status FROM scheduled_task WHERE status != 'deleted' ORDER BY id;" 2>&1 | tee /tmp/sched_out.txt
echo "" >> /tmp/sched_out.txt
echo "=== recent runs ===" >> /tmp/sched_out.txt
docker exec coze-mysql mysql -uroot -p"$(docker exec coze-mysql printenv MYSQL_ROOT_PASSWORD)" opencoze -e "SELECT id, task_id, status, started_at, LEFT(error_message,150) as err FROM scheduled_task_run ORDER BY id DESC LIMIT 10;" 2>&1 | tee -a /tmp/sched_out.txt
echo "" >> /tmp/sched_out.txt
echo "=== scheduler container ===" >> /tmp/sched_out.txt
docker ps -a --filter name=scheduler --no-trunc | tee -a /tmp/sched_out.txt
echo "" >> /tmp/sched_out.txt
echo "=== scheduler logs ===" >> /tmp/sched_out.txt
docker logs --tail 80 sylab-scheduler-service 2>&1 | tail -80 | tee -a /tmp/sched_out.txt
echo "DONE"
