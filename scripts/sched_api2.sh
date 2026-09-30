#!/usr/bin/env bash
set +e
echo "=== /schedule/ API ==="
curl -s http://localhost:9092/schedule/?scope=all 2>&1 | head -100
echo ""
echo "=== MySQL ==="
docker exec coze-mysql mysql -uroot -p"$(docker exec coze-mysql printenv MYSQL_ROOT_PASSWORD)" opencoze -e "SELECT id, title, schedule_type, next_run_time, last_run_time, run_count, status FROM scheduled_task WHERE status != 'deleted' ORDER BY id;" 2>&1
echo ""
echo "=== scheduler ==="
docker ps -a --filter name=scheduler --no-trunc 2>&1
echo ""
echo "=== logs ==="
docker logs --tail 100 sylab-scheduler-service 2>&1 | tail -100
