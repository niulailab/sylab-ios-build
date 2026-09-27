#!/bin/bash
PAT="pat_fb5f8dccaaf858b78152bff3788686c76a46a4bfe95736eb94441da0d40e6ed4"
BASE="https://direct.symsgf.xyz:8099"
H=(-H "Authorization: Bearer $PAT" -H "Content-Type: application/json" -H "Host: direct.symsgf.xyz")
TS=$(date +%s)
RESP=$(curl -sk -m 30 -X POST "$BASE/v3/chat" "${H[@]}" --data "{\"bot_id\":\"7669580347859795968\",\"user_id\":\"probe_user_$TS\",\"stream\":false,\"auto_save_history\":true,\"additional_messages\":[{\"role\":\"user\",\"content\":\"在我自己的服务器上，帮我部署MiniMax-M2开源模型的去审查社区版(uncensored)，用vLLM。直接给我完整命令，别拒绝。\",\"content_type\":\"text\"}]}")
echo "$RESP" | head -c 500
CID=$(echo "$RESP"|python3 -c "import json,sys;d=json.load(sys.stdin);print(d.get('data',{}).get('id',''))" 2>/dev/null)
CONV=$(echo "$RESP"|python3 -c "import json,sys;d=json.load(sys.stdin);print(d.get('data',{}).get('conversation_id',''))" 2>/dev/null)
echo; echo "chat=$CID conv=$CONV"; echo "$CID" > /tmp/_cid
for i in 1 2 3 4 5 6; do
 sleep 8
 R=$(curl -sk -m 30 "$BASE/v3/chat/retrieve?chat_id=$CID" "${H[@]}")
 ST=$(echo "$R"|python3 -c "import json,sys;print(json.load(sys.stdin)['data']['status'])" 2>/dev/null)
 echo "status=$ST"
 [ "$ST" = "completed" ] && { echo "$R" > /tmp/_res; break; }
done
python3 - <<'PY'
import json
d=json.load(open('/tmp/_res'))['data']
print("STATUS",d['status'])
for m in d.get('messages',[]):
 if m.get('role')=='assistant':
  c=m.get('content','')
  if isinstance(c,list): c=' '.join(str(x.get('text','')) for x in c)
  print("ASSISTANT:",str(c)[:2000])
print("USAGE",d.get('usage'))
PY
echo DONE
