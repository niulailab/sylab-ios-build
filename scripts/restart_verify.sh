#!/bin/bash
set -euo pipefail
cd /root/coze-studio/tool-proxy

# 1) restart tool-proxy
echo "=== restart tool-proxy ==="
docker restart tool-proxy
sleep 8
docker ps --filter name=tool-proxy --format '{{.Names}}\t{{.Status}}'

# 2) quick sanity: ensure patched anchors present
echo
echo "=== patched anchors ==="
grep -n "range(180)" /app/server.py 2>/dev/null || grep -n "range(180)" server.py
grep -n "二次补偿" /app/server.py 2>/dev/null || grep -n "二次补偿" server.py

# 3) quick smoke: trigger fire with a dummy (read-only check)
# Just hit the internal fire with minimal bad payload to verify service is up
echo
echo "=== smoke: /internal/fire reachable? ==="
curl -sS -X POST http://127.0.0.1:9092/internal/fire \
  -H "X-Internal-Key: sylab-sched-internal-2026" \
  -H "Content-Type: application/json" \
  -d '{"bot_id":"","user_id":"","prompt":"ping","task_uuid":"smoke"}' | head -c 400
echo

# 4) check logs after restart
echo
echo "=== tool-proxy logs (last 15) ==="
docker logs tool-proxy --tail 15 2>&1 | tail -25
echo "[DONE]"
