#!/bin/bash
PAT="pat_fb5f8dccaaf858b78152bff3788686c76a46a4bfe95736eb94441da0d40e6ed4"
BASE="https://direct.symsgf.xyz:8099"
H=(-H "Authorization: Bearer $PAT" -H "Content-Type: application/json" -H "Host: direct.symsgf.xyz")
CID="7690279208961966080"; CONV="7690279208899051520"
for i in $(seq 1 8); do
 R=$(curl -sk -m 30 "$BASE/v3/chat/retrieve?chat_id=$CID&conversation_id=$CONV" "${H[@]}")
 ST=$(echo "$R"|python3 -c "import json,sys;print(json.load(sys.stdin).get('data',{}).get('status',''))" 2>/dev/null)
 echo "status=$ST"
 [ "$ST" = "completed" ] && { echo "$R" > /tmp/_res; break; }
 sleep 6
done
python3 - <<'PY'
import json
d=json.load(open('/tmp/_res'))['data']
print("STATUS",d['status'],"USAGE",d.get('usage'))
for m in d.get('messages',[]):
 if m.get('role')=='assistant':
  c=m.get('content','')
  if isinstance(c,list): c=' '.join(str(x.get('text','')) for x in c)
  print("ASSISTANT:",str(c)[:2200])
PY
echo DONE
