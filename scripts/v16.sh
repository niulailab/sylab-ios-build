#!/bin/bash
echo "===== server.py 1440-1510 截图/内容区, 看有没有可复用的content转发 ====="
sed -n '1440,1510p' /root/coze-studio/tool-proxy/server.py
echo "[DONE]"
