#!/bin/bash
echo "=== scheduler_module.py first 95 lines ==="
sed -n '1,95p' /root/scheduler_module.py
echo ""
echo "=== how tool-proxy mounts scheduler_module ==="
grep -nE "scheduler_module|include_router|uvicorn.run|workers" /root/coze-studio/tool-proxy/server.py | head
echo ""
echo "=== tool-proxy process cmdline (worker count) ==="
ps aux | grep -E "tool.proxy|server.py|uvicorn" | grep -v grep
echo ""
echo "=== real title (hex check charset) ==="
docker exec coze-mysql mysql -uroot -pd3G8JG273iE8C4irRWJX opencoze -N -e "select title, hex(title) from sylab_scheduled_tasks where status='active';" 2>/dev/null
