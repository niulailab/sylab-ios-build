#!/bin/bash
MP=$(docker exec coze-mysql printenv MYSQL_ROOT_PASSWORD)
Q(){ docker exec coze-mysql mysql -uroot -p"$MP" opencoze -N -e "$1" 2>/dev/null; }
echo "===== openapi 全路径(确认后端真实路由) ====="
curl -s -m 15 http://localhost:9092/openapi.json | python3 -c "
import json,sys;d=json.load(sys.stdin)
ps=sorted(d['paths'].keys())
print('TOTAL',len(ps))
for p in ps: print(p, '|', ','.join(d['paths'][p].keys()))
"
echo "[DONE]"
