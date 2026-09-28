#!/bin/bash
echo "=== locate nginx config for 8099 ==="
grep -rln "8099" /etc/nginx/ 2>/dev/null | grep -v ".bak"
echo ""
echo "=== server blocks listening 8099 ==="
for f in $(grep -rln "8099" /etc/nginx/sites-enabled/ /etc/nginx/conf.d/ 2>/dev/null | grep -v bak); do
 echo "--- $f ---"
 grep -nE "listen|location|proxy_pass" "$f" | head -60
done
echo ""
echo "=== total server.py lines ==="
wc -l /root/coze-studio/tool-proxy/server.py
