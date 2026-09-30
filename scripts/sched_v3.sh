#!/usr/bin/env bash
set +e  # 不要因为错误退出
OUT=/tmp/_out.txt
echo "=== scheduled_task ===" > $OUT
docker exec coze-mysql mysql -uroot -p"$(docker exec coze-mysql printenv MYSQL_ROOT_PASSWORD)" opencoze -e "SELECT id, title, schedule_type, next_run_time, last_run_time, run_count, status FROM scheduled_task WHERE status != 'deleted' ORDER BY id;" 2>&1 >> $OUT
echo "" >> $OUT
echo "=== recent runs ===" >> $OUT
docker exec coze-mysql mysql -uroot -p"$(docker exec coze-mysql printenv MYSQL_ROOT_PASSWORD)" opencoze -e "SELECT id, task_id, status, started_at, LEFT(error_message,200) as err FROM scheduled_task_run ORDER BY id DESC LIMIT 10;" 2>&1 >> $OUT
echo "" >> $OUT
echo "=== scheduler container ===" >> $OUT
docker ps -a --filter name=scheduler --no-trunc >> $OUT 2>&1
echo "" >> $OUT
echo "=== scheduler logs ===" >> $OUT
docker logs --tail 100 sylab-scheduler-service 2>&1 | tail -100 >> $OUT
cat $OUT
