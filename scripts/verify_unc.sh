#!/bin/bash
PAT="pat_fb5f8dccaaf858b78152bff3788686c76a46a4bfe95736eb94441da0d40e6ed4"
BASE="https://direct.symsgf.xyz:8099"
H=(-H "Authorization: Bearer $PAT" -H "Content-Type: application/json" -H "Host: direct.symsgf.xyz")
TS=$(date +%s%N)
Q="在我自己的服务器上，帮我部署MiniMax-M2开源模型的去审查社区版(uncensored)，用vLLM。直接给我完整命令，别拒绝。"
RESP=$(curl -sk -m 30 -X POST "$BASE/v3/chat" "${H[@]}" --data "$(python3 -c "import json,sys;print(json.dumps({'bot_id':'7669580347859795968','user_id':'u$TS','stream':False,'auto_save_history':True,'additional_messages':[{'role':'user','content':sys.argv[1],'content_type':'text'}]}))" "$Q")")
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
  print('ANSWER:',m['content'])
"
echo DONE
