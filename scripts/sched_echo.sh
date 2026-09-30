#!/usr/bin/env bash
set +e
R=$(docker exec coze-mysql mysql -uroot -p"$(docker exec coze-mysql printenv MYSQL_ROOT_PASSWORD)" opencoze -e "SELECT id, title, schedule_type, next_run_time, last_run_time, run_count, status FROM scheduled_task WHERE status != 'deleted' ORDER BY id;" 2>&1)
R+=$'\n\n=== runs ===\n'
R+=$(docker exec coze-mysql mysql -uroot -p"$(docker exec coze-mysql printenv MYSQL_ROOT_PASSWORD)" opencoze -e "SELECT id, task_id, status, started_at, LEFT(error_message,200) as err FROM scheduled_task_run ORDER BY id DESC LIMIT 10;" 2>&1)
R+=$'\n\n=== scheduler ===\n'
R+=$(docker ps -a --filter name=scheduler --no-trunc 2>&1)
R+=$'\n\n=== logs ===\n'
R+=$(docker logs --tail 100 sylab-scheduler-service 2>&1 | tail -100)
echo "$R"
