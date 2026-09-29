#!/bin/bash
echo "===== compose tool-proxy 段 ====="
awk '/^  tool-proxy:/{f=1} f{print NR": "$0} f&&/^  [a-z]/&&NR>1&&!/^  tool-proxy:/{exit}' /root/coze-studio/docker/docker-compose.yml | head -40
echo ""
echo "===== grep environment/BOCHA in compose ====="
grep -n "BOCHA\|environment" /root/coze-studio/docker/docker-compose.yml | head -20
echo "[DONE]"
