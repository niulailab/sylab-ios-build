#!/bin/bash
echo "===== 定位 coze server 容器 ====="
docker ps --format '{{.Names}}\t{{.Status}}' | grep -iE "coze-server|coze_server|^server|coze-web|backend"
echo ""
echo "===== 重启前时间 ====="
date '+%F %T'
echo "[DONE]"
