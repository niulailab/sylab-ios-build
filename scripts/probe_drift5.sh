#!/bin/bash
echo "=== both active tasks full ==="
docker exec coze-mysql mysql -uroot -pd3G8JG273iE8C4irRWJX opencoze --default-character-set=utf8mb4 -e "SELECT id,task_uuid,user_id,conversation_id,status,schedule_expr,next_run_at,last_run_at,last_status,run_count,LEFT(prompt,80) p FROM sylab_scheduled_tasks WHERE status='active' ORDER BY id \G" 2>/dev/null
echo
echo "=== FIRE_URL / FIRE_KEY definitions ==="
grep -nE "FIRE_URL|FIRE_KEY|9088" /root/coze-studio/tool-proxy/server.py | head
echo
echo "=== locate chat-queue service on 9088 ==="
ss -ltnp 2>/dev/null | grep -E ":9088|:9091|:9089" 
docker ps --format '{{.Names}}\t{{.Ports}}' | grep -iE "queue|chat|9088|9091"
echo "[DONE]"
