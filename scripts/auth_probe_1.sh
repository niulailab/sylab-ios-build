#!/bin/bash
echo "=== existing auth helpers in server.py ==="
grep -nE "def .*(verify|resolve|parse|auth).*(session|pat|token|user)|session_key|personal_access|pat_|decode.*jwt|jwt.decode" /root/coze-studio/tool-proxy/server.py | head -30
echo ""
echo "=== MySQL: session & pat tables ==="
docker exec coze-mysql mysql -uroot -pd3G8JG273iE8C4irRWJX opencoze -N -e "show tables;" 2>/dev/null | grep -iE "session|pat|token|access|auth"
echo ""
echo "=== how chat-queue validates things (it uses server PAT). its internal check ==="
grep -nE "session|personal_access|pat|verify" /root/chat-queue-service/server.js | grep -iE "table|select|mysql|verify|jwt" | head
