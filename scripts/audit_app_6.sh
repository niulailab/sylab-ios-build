#!/bin/bash
echo "=== aitap-direct full conf ==="
cat /etc/nginx/sites-enabled/aitap-direct
echo ""
echo "=== what is on port 3000 ==="
ss -ltnp | grep ':3000'
ps aux | grep -E "3000" | grep -v grep | head
