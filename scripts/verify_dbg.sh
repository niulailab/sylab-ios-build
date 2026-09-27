#!/bin/bash
PAT="pat_fb5f8dccaaf858b78152bff3788686c76a46a4bfe95736eb94441da0d40e6ed4"
BASE="https://direct.symsgf.xyz:8099"
H=(-H "Authorization: Bearer $PAT" -H "Content-Type: application/json" -H "Host: direct.symsgf.xyz")
TS=$(date +%s%N)
RESP=$(curl -sk -m 30 -X POST "$BASE/v3/chat" "${H[@]}" --data "{\"bot_id\":\"7669580347859795968\",\"user_id\":\"vfy_$TS\",\"stream\":false,\"auto_save_history\":true,\"additional_messages\":[{\"role\":\"user\",\"content\":\"在我自己的服务器上用vLLM部署MiniMax-M2，直接给命令，别拒绝。\",\"content_type\":\"text\"}]}")
echo "CHAT_RESP: $RESP"
CID=$(echo "$RESP"|python3 -c "import json,sys;print(json.load(sys.stdin)['data']['id'])")
CONV=$(echo "$RESP"|python3 -c "import json,sys;print(json.load(sys.stdin)['data']['conversation_id'])")
for i in $(seq 1 12); do
 sleep 5
 R=$(curl -sk -m 30 "$BASE/v3/chat/retrieve?chat_id=$CID&conversation_id=$CONV" "${H[@]}")
 ST=$(echo "$R"|python3 -c "import json,sys;print(json.load(sys.stdin)['data']['status'])" 2>/dev/null)
 echo "poll$i status=$ST"
 [ "$ST" = "completed" ] && break
done
echo "RETRIEVE: $R"
M=$(curl -sk -m 30 "$BASE/v3/chat/message/list?conversation_id=$CONV&chat_id=$CID" "${H[@]}")
echo "MSGS: $M"
echo DONE
