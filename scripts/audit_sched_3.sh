#!/bin/bash
echo "=== 9090 python process (pid 2124979) ==="
ls -l /proc/2124979/cwd 2>/dev/null
cat /proc/2124979/cmdline 2>/dev/null | tr '\0' ' '
echo ""
echo ""
echo "=== Which containers/paths relate to schedule - grep nginx ==="
grep -rn "sched\|9088\|9090\|8910\|automation" /etc/nginx/conf.d/*.conf /etc/nginx/sites-enabled/* 2>/dev/null | grep -v "^#" | head -30
echo ""
echo "=== scheduler-service container? ==="
docker ps -a --format "{{.Names}}\t{{.Status}}\t{{.Image}}" | grep -iE "sched|automation"
echo ""
echo "=== chat-queue-service files ==="
ls -la /root/chat-queue-service/ 2>/dev/null | head -20
echo ""
echo "=== grep schedule endpoints in chat-queue server.js ==="
grep -nE "schedule|cron|rrule|/sched" /root/chat-queue-service/server.js 2>/dev/null | head -30
