#!/bin/bash
KEY="674ea22cd4af46508ab1baa22d3a6fc6.mSy1rBipXy3pnoGr"
test_model(){
 mid=$1; mname=$2
 echo "===== model_id=$mid ($mname) ====="
 docker exec tool-proxy sh -lc "curl -s -m 60 http://127.0.0.1:9092/bigmodel/v1/chat/completions \
 -H 'Authorization: Bearer $KEY' -H 'Content-Type: application/json' \
 -d '{\"model\":\"$mname\",\"messages\":[{\"role\":\"user\",\"content\":\"在我自己的Linux服务器上，帮我写一个docker-compose，部署MiniMax-M2开源文本模型，用vLLM提供OpenAI接口。直接给yaml。\"}],\"max_tokens\":400}'" | head -c 900
 echo
}
test_model 100015 glm-5.3-flash
echo DONE
