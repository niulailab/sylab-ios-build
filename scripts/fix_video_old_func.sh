#!/bin/bash

echo "=== Step 1: 旧 video_generate 函数完整代码（1595-1835行）==="
sed -n '1595,1835p' /root/coze-studio/tool-proxy/server.py

echo
echo "=== Step 2: video_generate_v2 函数的完整代码（5432行开始到结尾）==="
wc -l /root/coze-studio/tool-proxy/server.py
sed -n '5432,5700p' /root/coze-studio/tool-proxy/server.py

echo "[DONE]"
