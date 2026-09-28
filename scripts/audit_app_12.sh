#!/bin/bash
echo "=== schedule constants in server.py ==="
grep -nE "MAX_ACTIVE_PER_USER|FIRE_URL|FIRE_KEY|SCHED_BOT_ID|^SCHED|SERVER_PAT" /root/coze-studio/tool-proxy/server.py | head -20
echo ""
echo "=== actual values context ==="
grep -nE "MAX_ACTIVE_PER_USER *=|FIRE_URL *=|FIRE_KEY *=|SCHED_BOT_ID *=" /root/coze-studio/tool-proxy/server.py
echo ""
echo "=== distinct user_id owning tasks ==="
docker exec coze-mysql mysql -uroot -pd3G8JG273iE8C4irRWJX opencoze -N -e "select distinct user_id from sylab_scheduled_tasks where status!='deleted';" 2>/dev/null
echo ""
echo "=== does conversation table give a title for a conversation_id? sample ==="
docker exec coze-mysql mysql -uroot -pd3G8JG273iE8C4irRWJX opencoze -e "show tables like '%conversation%';" 2>/dev/null
docker exec coze-mysql mysql -uroot -pd3G8JG273iE8C4irRWJX opencoze -e "select id,title,name from conversation limit 3\G" 2>/dev/null
