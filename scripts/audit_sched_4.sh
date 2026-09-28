#!/bin/bash
echo "=== nginx 330-370 ==="
sed -n '330,370p' /etc/nginx/sites-enabled/default

echo ""
echo "=== server.js schedule section (760 to end) ==="
wc -l /root/chat-queue-service/server.js
sed -n '760,1000p' /root/chat-queue-service/server.js
