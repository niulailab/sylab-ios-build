#!/bin/bash
PAT="pat_fb5f8dccaaf858b78152bff3788686c76a46a4bfe95736eb94441da0d40e6ed4"
BASE="https://direct.symsgf.xyz:8099"
H=(-H "Authorization: Bearer $PAT" -H "Content-Type: application/json" -H "Host: direct.symsgf.xyz")
TS=$(date +%s%N)
# 用一张公网可访问小图，问颜色/内容
BODY=$(python3 <<'PY'
import json
print(json.dumps({"bot_id":"7669580347859795968","user_id":"img","stream":False,"auto_save_history":True,"additional_messages":[{"role":"user","content":"用一句话描述这张图里有什么：https://images.unsplash.com/photo-1514888286974-6c03e2ca1dba?w=200","content_type":"text"}]}))
PY
)
RESP=$(curl -sk -m 30 -X POST "$BASE/v3/chat" "${H[@]}" --data "$BODY")
CID=$(echo "$RESP"|python3 -c "import json,sys;print(json.load(sys.stdin)['data']['id'])")
CONV=$(echo "$RESP"|python3 -c "import json,sys;print(json.load(sys.stdin)['data']['conversation_id'])")
for i in $(seq 1 16); do
 sleep 5
 R=$(curl -sk -m 30 "$BASE/v3/chat/retrieve?chat_id=$CID&conversation_id=$CONV" "${H[@]}")
 ST=$(echo "$R"|python3 -c "import json,sys;print(json.load(sys.stdin)['data']['status'])" 2>/dev/null)
 [ "$ST" = "completed" ] && break
done
M=$(curl -sk -m 30 "$BASE/v3/chat/message/list?conversation_id=$CONV&chat_id=$CID" "${H[@]}")
echo "$M" | python3 -c "
import json,sys
d=json.load(sys.stdin)
for m in d.get('Messages',[]):
 if m.get('role')=='assistant' and m.get('type')=='answer':
  print('IMG_ANSWER:',m['content'])
"
echo DONE
