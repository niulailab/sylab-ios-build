#!/bin/bash
echo "=== once-type tasks status vs their run records ==="
docker exec coze-mysql mysql -uroot -pd3G8JG273iE8C4irRWJX opencoze -e "
select t.task_uuid,t.title,t.schedule_expr,t.status,t.consecutive_failures,t.last_status,
 (select count(*) from sylab_schedule_runs r where r.task_uuid=t.task_uuid) runs
from sylab_scheduled_tasks t where t.schedule_type='once' order by t.id;" 2>/dev/null
echo ""
echo "=== any failed runs ever? ==="
docker exec coze-mysql mysql -uroot -pd3G8JG273iE8C4irRWJX opencoze -e "select result_status,count(*) from sylab_schedule_runs group by result_status;" 2>/dev/null
echo ""
echo "=== scheduler_module mount in server.py ==="
grep -nE "scheduler_module|import_module|exec\(|from scheduler" /root/coze-studio/tool-proxy/server.py | head
