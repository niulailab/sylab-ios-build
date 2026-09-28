#!/bin/bash
SK=$(docker exec coze-mysql mysql -uroot -pd3G8JG273iE8C4irRWJX opencoze -N -e "select session_key from user where id=7666848996043784192;" 2>/dev/null)
echo "=== via 9091 /schedule/list scope=all with cookie ==="
curl -s -m 10 -X POST http://127.0.0.1:9091/schedule/list \
 -H "Content-Type: application/json" --cookie "session_key=$SK" -d '{"scope":"all"}' \
 | python3 -c "import json,sys;d=json.load(sys.stdin);print('code',d['code']);print('tasks',json.loads(d['data'])['count'] if d['code']==0 else d.get('msg'))"
echo ""
echo "=== toggle then list (pause task2, expect active->paused) ==="
TU=cbf88122-e0fb-4d98-afc9-9341ccd5c14d
curl -s -m 10 -X POST http://127.0.0.1:9091/schedule/toggle \
 -H "Content-Type: application/json" --cookie "session_key=$SK" \
 -d "{\"task_uuid\":\"$TU\",\"action\":\"pause\"}"
echo ""
docker exec coze-mysql mysql -uroot -pd3G8JG273iE8C4irRWJX opencoze -N -e "select status from sylab_scheduled_tasks where task_uuid='$TU';" 2>/dev/null
echo "=== resume back ==="
curl -s -m 10 -X POST http://127.0.0.1:9091/schedule/toggle \
 -H "Content-Type: application/json" --cookie "session_key=$SK" \
 -d "{\"task_uuid\":\"$TU\",\"action\":\"resume\"}"
echo ""
docker exec coze-mysql mysql -uroot -pd3G8JG273iE8C4irRWJX opencoze -N -e "select status from sylab_scheduled_tasks where task_uuid='$TU';" 2>/dev/null
