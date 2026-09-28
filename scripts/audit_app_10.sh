#!/bin/bash
echo "=== locate real schedule endpoints in server.py ==="
grep -nE "@app\.(post|get|api_route).*schedule|def .*schedule|scheduler_module|import.*sched" /root/coze-studio/tool-proxy/server.py | head -40
echo ""
echo "=== nginx default lines 70-115 (root / and api) ==="
sed -n '70,115p' /etc/nginx/sites-enabled/default
