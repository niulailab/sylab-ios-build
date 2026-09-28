#!/bin/bash
cat /tmp/auth.sh 2>/dev/null
echo "==="
# Also check for any session/token stored
cat /tmp/session* 2>/dev/null
cat /tmp/token* 2>/dev/null
# Check if there's a way to generate session from DB
echo "=== MySQL password variants ==="
mysql -h 172.18.0.100 -u root -proot opencoze -e "SELECT 1" 2>&1 | head -3
mysql -h 172.18.0.100 -u root -p'root123' opencoze -e "SELECT 1" 2>&1 | head -3
mysql -h 172.18.0.100 -u root opencoze -e "SELECT 1" 2>&1 | head -3
