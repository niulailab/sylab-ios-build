#!/bin/bash
echo "=== all nginx server_name + listen (enabled, non-bak) ==="
for f in /etc/nginx/sites-enabled/* /etc/nginx/conf.d/*.conf; do
 echo "--- $f ---"
 grep -nE "listen|server_name|default_server" "$f" | grep -v "^\s*#"
done
echo ""
echo "=== where does direct.symsgf.xyz appear ==="
grep -rln "direct.symsgf" /etc/nginx/ 2>/dev/null | grep -v bak
echo ""
echo "=== 9092 exposed via https? which public route proxies to 9092 ==="
grep -rnE "proxy_pass http://127.0.0.1:9092" /etc/nginx/sites-enabled/ | head
