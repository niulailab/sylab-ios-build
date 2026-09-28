#!/bin/bash
echo "=== 1. Listening ports (scheduler related) ==="
ss -tlnp | grep -E "9088|9090|8989|sched" 

echo ""
echo "=== 2. Running containers ==="
docker ps --format "{{.Names}}\t{{.Image}}\t{{.Status}}" | grep -iE "sched|task|cron|job|9088"

echo ""
echo "=== 3. All containers ==="
docker ps --format "{{.Names}}\t{{.Ports}}" | head -40

echo ""
echo "=== 4. scheduler service health ==="
curl -s http://172.18.0.1:9088/health 2>/dev/null
echo ""
curl -s http://127.0.0.1:9088/health 2>/dev/null
echo ""

echo ""
echo "=== 5. Find scheduler source dirs ==="
ls -d /root/*sched* /root/*cron* /root/coze-studio/*sched* 2>/dev/null
find /root -maxdepth 3 -type d -iname "*schedul*" 2>/dev/null | grep -v node_modules | head
find /root -maxdepth 3 -type f -iname "*schedul*" 2>/dev/null | grep -vE "node_modules|.git/|site-packages" | head -20
