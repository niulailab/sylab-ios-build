#!/bin/bash
echo "===== server.py 通知list/相关函数定位 ====="
grep -n "notifications/list\|def list_notification\|jsonify\|JSON serializable\|created_at\|strftime\|isoformat" /root/coze-studio/tool-proxy/server.py | grep -iE "notif|list|datetime|created" | head -20
echo "[DONE]"
