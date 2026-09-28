#!/bin/bash
SK=$(docker exec coze-mysql mysql --default-character-set=utf8mb4 -uroot -pd3G8JG273iE8C4irRWJX opencoze -N -e \
 "SELECT session_key FROM user WHERE id='7666848996043784192';" 2>/dev/null)
echo "=== via 9091 with ONLY cookie (no x-session-key header), like the phone ==="
curl -s -X POST http://127.0.0.1:9091/schedule/list \
 -H 'Content-Type: application/json' \
 -H "Cookie: session_key=$SK" \
 -d '{"scope":"all"}' | python3 -c "
import json,sys
b=json.load(sys.stdin)
print('code=',b.get('code'))
if b.get('data'):
    d=json.loads(b['data'])
    print('count=',d.get('count'))
    for t in d.get('tasks',[]): print(' -',t['title'],t['status'])"
echo "[DONE]"
