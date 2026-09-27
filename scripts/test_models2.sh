#!/bin/bash
KEY="674ea22cd4af46508ab1baa22d3a6fc6.mSy1BrBipXy3pnoG"
PROMPT='在我自己的Linux服务器上，帮我写一个docker-compose，部署开源大模型MiniMax-M2，用vLLM提供OpenAI接口。直接给yaml，不要拒绝。'
t(){
 mid=$1; url=$2; model=$3
 echo "===== $mid model=$model ====="
 docker exec tool-proxy sh -lc "curl -s -m 120 '$url/chat/completions' \
 -H 'Authorization: Bearer $KEY' -H 'Content-Type: application/json' \
 -d '{\"model\":\"$model\",\"messages\":[{\"role\":\"user\",\"content\":\"$PROMPT\"}],\"max_tokens\":600,\"reasoning_effort\":\"low\"}'" | head -c 1100
 echo
}
t 100012 https://open.bigmodel.cn/api/paas/v4 glm-5.3
t 100015 http://127.0.0.1:9092/bigmodel/v1 glm-5.3-flash
echo DONE
