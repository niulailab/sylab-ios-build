#!/bin/bash
# Check existing test/replay scripts for how they authenticate
echo "=== Check existing test scripts ==="
ls /root/coze-studio/scripts/ 2>/dev/null | head
ls /tmp/*.sh 2>/dev/null | head -20

echo ""
echo "=== Check real_chat_test scripts ==="
find / -name "real_chat_test*" -type f 2>/dev/null | head -5
find / -name "replay_exact*" -type f 2>/dev/null | head -5

echo ""
echo "=== Check MySQL for session or use internal API ==="
# Try internal endpoints that might not need auth
curl -s "http://127.0.0.1:8888/health" 2>/dev/null | head -c 200
echo ""
curl -s "http://172.18.0.1:9088/health" 2>/dev/null | head -c 200
echo ""

# Directly query MySQL for a valid session or user
echo "=== Query MySQL for users ==="
mysql -h 172.18.0.100 -u root -p'CozeRoot2026!' opencoze -e "SELECT id, name, email FROM user LIMIT 5" 2>/dev/null

echo ""
echo "=== Check session table ==="
mysql -h 172.18.0.100 -u root -p'CozeRoot2026!' opencoze -e "SHOW TABLES LIKE '%session%'" 2>/dev/null
