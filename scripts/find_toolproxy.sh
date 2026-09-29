#!/bin/bash
echo "=== who listens 9092 ==="
ss -ltnp 2>/dev/null | grep 9092
echo
echo "=== all python processes ==="
ps -ef | grep -i python | grep -v grep
echo
echo "=== supervisord? ==="
which supervisord systemctl 2>/dev/null
systemctl list-units --type=service 2>/dev/null | grep -iE "tool|proxy|supervis|python" | head
echo
echo "=== crontab / rc.local / nohup ==="
grep -iE "server\.py|tool-proxy" /etc/crontab /root/.bashrc /root/.profile /root/nohup* 2>/dev/null | head
cat /etc/rc.local 2>/dev/null | grep -iE "tool-proxy|server" || true
echo
echo "=== selfheal bak exists? ==="
ls -lht /root/coze-studio/tool-proxy/server.py.bak_selfheal* 2>/dev/null
echo
echo "=== check docker ==="
docker ps 2>/dev/null | grep -iE "tool|proxy" || echo "(no docker tool-proxy)"
echo "[DONE]"
