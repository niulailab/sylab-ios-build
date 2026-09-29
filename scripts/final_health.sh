#!/bin/bash
echo "=== /schedule/health ==="
curl -sS http://127.0.0.1:9092/schedule/health | python3 -m json.tool
echo
echo "=== /schedule/list (this user, first) ==="
curl -sS -X POST http://127.0.0.1:9092/schedule/list \
  -H "Content-Type: application/json" \
  -d '{"user_id":"7666848996043784192","count":5}' | python3 -c "
import json,sys
d = json.load(sys.stdin)
print('code:', d.get('code'))
for t in d.get('data',{}).get('tasks',[])[:3]:
    print(f\"  {t.get('task_uuid')[:16]} | status={t.get('status')} | last={t.get('last_status')} | next={t.get('next_run_at')} | {t.get('title','')[:20]}\")
"
echo
echo "=== docker logs tool-proxy last 5 ==="
docker logs tool-proxy --tail 5 2>&1 | tail -6
echo
echo "=== patched file still synced? ==="
docker exec tool-proxy grep -c "range(180)" /app/server.py
docker exec tool-proxy grep -c "二次补偿" /app/server.py
echo "[DONE]"
