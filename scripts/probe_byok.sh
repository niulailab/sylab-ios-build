#!/bin/bash
echo "=== llm related containers ==="
docker ps --format '{{.Names}}\t{{.Image}}\t{{.Ports}}' | grep -iE "llm|proxy|chat|model"
echo
echo "=== locate llm-proxy code ==="
for d in /root/coze-studio/llm-proxy /root/llm-proxy /root/coze-studio; do
 [ -d "$d" ] && echo "DIR $d" && ls "$d" 2>/dev/null | head
done
echo
echo "=== find python/js handling chat completions & api key injection ==="
grep -rIln --exclude-dir=node_modules --exclude-dir=.git \
 -e "chat/completions" -e "Authorization" -e "api_key" -e "base_url" \
 /root/coze-studio/llm-proxy 2>/dev/null | head
echo "[DONE]"
