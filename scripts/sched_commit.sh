#!/usr/bin/env bash
set +e
OUT=""
OUT+="=== scheduled_task ===\n"
OUT+=$(docker exec coze-mysql mysql -uroot -p"$(docker exec coze-mysql printenv MYSQL_ROOT_PASSWORD)" opencoze -e "SELECT id, title, schedule_type, next_run_time, last_run_time, run_count, status FROM scheduled_task WHERE status != 'deleted' ORDER BY id;" 2>&1)
OUT+="\n\n=== recent runs ===\n"
OUT+=$(docker exec coze-mysql mysql -uroot -p"$(docker exec coze-mysql printenv MYSQL_ROOT_PASSWORD)" opencoze -e "SELECT id, task_id, status, started_at, LEFT(error_message,200) as err FROM scheduled_task_run ORDER BY id DESC LIMIT 10;" 2>&1)
OUT+="\n\n=== scheduler container ===\n"
OUT+=$(docker ps -a --filter name=scheduler --no-trunc 2>&1)
OUT+="\n\n=== scheduler logs ===\n"
OUT+=$(docker logs --tail 100 sylab-scheduler-service 2>&1 | tail -100)
echo -e "$OUT" > /tmp/_sched_result.txt
echo "RESULT_WRITTEN"
