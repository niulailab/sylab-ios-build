#!/bin/bash
echo "=== sylab_scheduled_tasks schema ==="
docker exec coze-mysql mysql -uroot -pd3G8JG273iE8C4irRWJX opencoze -e "show create table sylab_scheduled_tasks\G" 2>/dev/null
echo "=== sylab_schedule_runs schema ==="
docker exec coze-mysql mysql -uroot -pd3G8JG273iE8C4irRWJX opencoze -e "show create table sylab_schedule_runs\G" 2>/dev/null
echo "=== task count by status ==="
docker exec coze-mysql mysql -uroot -pd3G8JG273iE8C4irRWJX opencoze -e "select status,count(*) from sylab_scheduled_tasks group by status;" 2>/dev/null
echo "=== runs count ==="
docker exec coze-mysql mysql -uroot -pd3G8JG273iE8C4irRWJX opencoze -e "select count(*) from sylab_schedule_runs;" 2>/dev/null
