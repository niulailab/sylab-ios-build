#!/bin/bash
grep -A3 "if tool_only:" /root/coze-studio/tool-proxy/server.py | head -5
echo "---"
docker restart tool-proxy 2>/dev/null && echo "restarted" || echo "restart failed"
