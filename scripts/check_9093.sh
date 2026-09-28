#!/bin/bash
echo "=== 9093 listener ==="
ss -ltnp 2>/dev/null | grep 9093 || echo "no 9093 listener"
echo "=== what is 9093 proc ==="
PID=$(ss -ltnp 2>/dev/null | grep 9093 | grep -oE 'pid=[0-9]+' | head -1 | cut -d= -f2)
[ -n "$PID" ] && { ls -l /proc/$PID/cwd; tr '\0' ' ' < /proc/$PID/cmdline; echo; }
echo "=== test upload to 9093 ==="
echo "probe_bug2_$(date +%s) content" > /tmp/_probe_up.txt
curl -s -X POST 'http://127.0.0.1:9093/api/files/upload' \
 -H 'X-Conversation-Id: probe_bug2' \
 -H 'X-File-Name: probe_bug2.txt' \
 --data-binary @/tmp/_probe_up.txt
echo
echo "[DONE]"
