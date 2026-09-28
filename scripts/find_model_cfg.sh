#!/bin/bash
# Current env
grep -n "MODEL_API_KEY\|MODEL_NAME\|GLM\|ZHIPU\|BIGMODEL\|REASONING" /root/coze-studio/docker/.env 2>/dev/null | grep -v "^#" | head -20
echo "==="
# Check model config for glm
docker exec coze-server cat /app/resources/conf/model/conf.yaml 2>/dev/null | head -60
echo "==="
# Or find active model config
docker exec coze-server find /app/resources/conf -name "*.yaml" -path "*/model/*" -not -path "*/template/*" 2>/dev/null
