#!/bin/bash
cd /root/coze-studio/tool-proxy
F=server.py

echo "=== 1) registered /internal/ routes in tool-proxy ==="
grep -nE "app\.(post|get|put|delete)\(['\"]/internal" "$F"
echo
echo "=== 2) scheduler loop startup ==="
grep -nE "scheduler.*loop started|_scheduler_loop|create_task.*_scheduler" "$F"
echo
echo "=== 3) browser_service selfheal patch still in place? ==="
grep -nE "_reset_agent_session|self-heal|_attempt" /root/coze-studio/browser-service/browser_service.py | head
echo
echo "=== 4) prelude injection still in code_exec_server.js? ==="
grep -nE "prelude|_PUBLIC_BASE|FILE_SERVICE|upload_file" /root/code_exec_server.js | head
echo
echo "=== 5) test /scheduler/status or similar ==="
curl -sS -X GET http://127.0.0.1:9092/scheduler/status 2>&1 | head -c 300
echo
echo
echo "=== 6) test internal/health-like ==="
curl -sS -X GET http://127.0.0.1:9092/ 2>&1 | head -c 300
echo
echo
echo "=== 7) list all routes ==="
docker exec tool-proxy python3 -c "
import sys; sys.path.insert(0,'/app')
import server
for r in server.app.routes:
    if hasattr(r,'path'): print(getattr(r,'methods',''), r.path)
" 2>&1 | grep -iE "sched|internal|fire" | head -20
echo "[DONE]"
