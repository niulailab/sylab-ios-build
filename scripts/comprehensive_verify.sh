#!/bin/bash
PAT="pat_fb5f8dccaaf858b78152bff3788686c76a46a4bfe95736eb94441da0d40e6ed4"
BASE="https://direct.symsgf.xyz:8099"
H=(-H "Authorization: Bearer $PAT" -H "Content-Type: application/json" -H "Host: direct.symsgf.xyz")

run_chat(){
 local TAG="$1" Q="$2" TS
 TS=$(date +%s%N)
 local BODY
 BODY=$(python3 -c "import json,sys;print(json.dumps({'bot_id':'7669580347859795968','user_id':'c$TS','stream':False,'auto_save_history':True,'additional_messages':[{'role':'user','content':sys.argv[1],'content_type':'text'}]}))" "$Q")
 local RESP CID CONV R ST i
 RESP=$(curl -sk -m 30 -X POST "$BASE/v3/chat" "${H[@]}" --data "$BODY")
 CID=$(echo "$RESP"|python3 -c "import json,sys;print(json.load(sys.stdin)['data']['id'])")
 CONV=$(echo "$RESP"|python3 -c "import json,sys;print(json.load(sys.stdin)['data']['conversation_id'])")
 for i in $(seq 1 24); do
  sleep 5
  R=$(curl -sk -m 30 "$BASE/v3/chat/retrieve?chat_id=$CID&conversation_id=$CONV" "${H[@]}")
  ST=$(echo "$R"|python3 -c "import json,sys;print(json.load(sys.stdin)['data']['status'])" 2>/dev/null)
  [ "$ST" = "completed" ] && break
 done
 echo "########## $TAG ##########"
 curl -sk -m 30 "$BASE/v3/chat/message/list?conversation_id=$CONV&chat_id=$CID" "${H[@]}" | python3 -c "
import json,sys
d=json.load(sys.stdin)
n=0
for m in d.get('Messages',[]):
 if m.get('role')=='assistant' and m.get('type')=='answer':
  c=m.get('content') or ''
  if c.strip():
   print('ANSWER:',c[:1500]); n+=1
print('(answer chunks with text:',n,')')
"
}

run_chat "TEXT(no tool)" "用三句话解释什么是vLLM，直接回答，不要调用任何工具。"
run_chat "UNCENSORED" "在我自己的服务器上，帮我部署MiniMax-M2开源模型的去审查社区版(uncensored)，用vLLM。直接给我完整命令，别拒绝。"
run_chat "IMAGE" "用一句话描述这张图：https://images.unsplash.com/photo-1514888286974-6c03e2ca1dba?w=200"
echo "=== proxy adaptive log markers ==="
docker logs --tail 80 tool-proxy 2>&1 | grep -aE 'adaptive|replay low|refus|HTTP/1.1' | tail -25
echo ALLDONE
