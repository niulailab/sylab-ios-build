#!/bin/bash
echo "===== TIME ====="; date
MC=coze-mysql
runmysql(){ docker exec -e Q="$1" "$MC" sh -lc 'mysql -uroot -p"$MYSQL_ROOT_PASSWORD" -N -e "$Q" 2>/dev/null'; }
PAT="pat_fb5f8dccaaf858b78152bff3788686c76a46a4bfe95736eb94441da0d40e6ed4"

# 找一个消息>50的会话（任意，PAT是平台级）
CID=$(runmysql "SELECT conversation_id FROM opencoze.message GROUP BY conversation_id HAVING COUNT(*)>100 ORDER BY COUNT(*) DESC LIMIT 1;")
echo "target conv: $CID count=$(runmysql "SELECT COUNT(*) FROM opencoze.message WHERE conversation_id=$CID;")"

for P in 1 2 3 4; do
echo "===== page$P (Bearer PAT) ====="
curl -s -m 10 -X POST "http://127.0.0.1:9091/v1/conversation/message/list" \
  -H 'Content-Type: application/json' -H "Authorization: Bearer $PAT" \
  -d "{\"conversation_id\":\"$CID\",\"page_num\":$P,\"page_size\":50}" \
  | python3 -c "
import sys,json
raw=sys.stdin.read()
try: d=json.loads(raw)
except: print('NONJSON',raw[:200]); raise SystemExit
print('code=',d.get('code'),'msg=',d.get('msg'))
data=d.get('data')
def cnt(x):
  if isinstance(x,list):return len(x)
  if isinstance(x,dict):
    for k in ('messages','items','list','data'):
      if isinstance(x.get(k),list):return (k,len(x[k]))
  return type(x).__name__
print('data=',cnt(data))
if isinstance(data,dict): print('keys=',list(data.keys()),'has_more=',data.get('has_more'))
"
done
echo "===== DONE ====="
