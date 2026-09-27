#!/bin/bash
echo "===== TIME ====="; date
PAT="pat_fb5f8dccaaf858b781524ff3788686c76a46a4bfe95736eb94441da0d40e6ed4"
CID=7688397794641444864
for P in 1 2 3; do
curl -s -m 10 -X POST "http://127.0.0.1:9091/v1/conversation/message/list" \
  -H 'Content-Type: application/json' -H "Authorization: Bearer $PAT" \
  -d "{\"conversation_id\":\"$CID\",\"page_num\":$P,\"page_size\":50}"
echo
done > /tmp/_pages.json
python3 - <<'PY'
import json
lines=open('/tmp/_pages.json').read().strip().split('\n')
ids_per=[]
for ln in lines:
    d=json.loads(ln); data=d['data']
    msgs = data if isinstance(data,list) else data.get('messages') or data.get('items') or []
    ids=[m.get('id') or m.get('message_id') for m in msgs]
    ids_per.append(ids)
    print('page ids first3:', ids[:3], '... last:', ids[-1])
s1,s2,s3=[set(x) for x in ids_per]
print('p1∩p2 =',len(s1&s2),' p2∩p3 =',len(s2&s3))
PY
echo "===== DONE ====="
