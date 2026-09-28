#!/bin/bash
# Find ZHIPU_UPSTREAM and any API keys in config
grep -n "ZHIPU_UPSTREAM\|ZHIPU\|zhipu" /root/coze-studio/tool-proxy/server.py | head -10
echo "==="
# Check coze-server config for the API key it uses
docker exec coze-server env 2>/dev/null | grep -iE "ZHIPU|GLM|BIGMODEL|API_KEY" | head -10
echo "==="
# Check coze-server config files
docker exec coze-server find /app -name "*.yaml" -o -name "*.yml" -o -name "*.json" -o -name "*.toml" 2>/dev/null | head -20
echo "==="
# Grep for zhipu key pattern in coze-studio
grep -rn "sk-[a-zA-Z0-9]\{20,\}" /root/coze-studio/conf/ 2>/dev/null | head -5
grep -rn "sk-[a-zA-Z0-9]\{20,\}" /root/coze-studio/docker/ 2>/dev/null | grep -v ".pyc" | head -10
