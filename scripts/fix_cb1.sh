#!/bin/bash
SP=/root/coze-studio/tool-proxy/server.py
echo "=== 1) tool-proxy _callback_coze 完整代码（看发了什么鉴权）==="
sed -n '5531,5578p' $SP
echo
echo "=== 2) coze-server 端 callback 路由实现位置 ==="
docker exec coze-server bash -c "grep -rn 'video/callback' /app 2>/dev/null | head" 2>/dev/null || echo "/app 没找到"
docker exec coze-server bash -c "ls / 2>/dev/null" | tr ' ' '\n' | head -30
echo "[DONE]"
