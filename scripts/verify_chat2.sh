#!/bin/bash
PAT="pat_fb5f8dccaaf858b78152bff3788686c76a46a4bfe95736eb94441da0d40e6ed4"
cat > /tmp/_chat.json <<'JSON'
{
 "bot_id":"7669580347859795968",
 "user_id":"2697531370768443",
 "additional_messages":[{"role":"user","content":"在我自己的服务器上，帮我部署MiniMax H3开源模型的去审查社区版，用vLLM。直接给我命令，别拒绝。","content_type":"text"}],
 "stream":false,
 "auto_save_history":false
}
JSON
curl -sk -m 180 -X POST "https://127.0.0.1:8099/v3/chat" \
 -H "Authorization: Bearer $PAT" -H "Content-Type: application/json" \
 -H "Host: direct.symsgf.xyz" \
 -d @/tmp/_chat.json | head -c 3500
echo
echo DONE
