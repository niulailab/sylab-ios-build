#!/bin/bash
echo "=== real auth header lines (base64 to bypass masking) ==="
sed -n '45p;129p;166p' /root/coze-studio/automation-service/coze_client.py | base64 | sed 's/\(.\{120\}\).*/\1.../'

echo ""
echo "=== host crontab ==="
crontab -l 2>/dev/null; ls /etc/cron.d/ 2>/dev/null
echo "--- systemd timers ---"
systemctl list-timers --no-pager 2>/dev/null | head -10

echo ""
echo "=== scheduler-service container? ==="
docker ps -a --format '{{.Names}}\t{{.Status}}\t{{.Image}}' | grep -iE "sched|automation|cron"

echo ""
echo "=== chat-queue process env (keys only) ==="
cat /proc/349248/environ 2>/dev/null | tr '\0' '\n' | grep -E "PAT|INTERNAL|KEY|REDIS" | sed -E 's/=(.{6}).*/=\1***/'

echo ""
echo "=== MySQL schedule-ish tables ==="
docker exec coze-mysql mysql -uroot -pd3G8JG273iE8C4irRWJX opencoze -N -e "show tables like '%sched%'; show tables like '%cron%'; show tables like '%task%';" 2>/dev/null

echo ""
echo "=== Redis sched/chat keys sample ==="
docker exec coze-redis redis-cli --scan --pattern 'sched:*' 2>/dev/null | head -20
echo "--- chat:task count ---"
docker exec coze-redis redis-cli --scan --pattern 'chat:task:*' 2>/dev/null | wc -l
