#!/bin/bash
echo "=== nginx routes for automation/schedule (active conf only) ==="
grep -nE "8910|automation|schedule|/api/v1" /etc/nginx/sites-enabled/default

echo ""
echo "=== routers dir ==="
ls -la /root/coze-studio/automation-service/routers/

echo ""
echo "=== app_state.py ==="
cat /root/coze-studio/automation-service/app_state.py

echo ""
echo "=== models.py ==="
cat /root/coze-studio/automation-service/models.py
