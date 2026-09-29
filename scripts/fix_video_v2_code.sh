#!/bin/bash

echo "=== Step 1: 看 video_generate_v2 函数代码（从第5432行开始）==="
sed -n '5432,5600p' /root/coze-studio/tool-proxy/server.py

echo
echo "=== Step 2: 看旧的 video_generate 函数（第1596行，作为对比）==="
sed -n '1596,1700p' /root/coze-studio/tool-proxy/server.py

echo
echo "=== Step 3: 查 video_generate_v2 的路由注册 ==="
grep -n "video_generate\|video/generate\|video/status" /root/coze-studio/tool-proxy/server.py | head -20

echo "[DONE]"
