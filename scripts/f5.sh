#!/bin/bash
echo "===== 执行补丁 ====="
python3 /root/coze-studio/tool-proxy/patch_server.py 2>&1 || python3 scripts/patch_server.py 2>&1
echo ""
echo "===== 确认目标镜像存在 ====="
docker images | grep -E "tool-proxy" 
echo ""
echo "===== compose 命令版本 ====="
(docker compose version 2>/dev/null || docker-compose version 2>/dev/null) | head -1
echo "[DONE]"
