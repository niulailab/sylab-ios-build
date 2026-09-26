#!/bin/bash
set +e
echo "===== certs SAN ====="
for c in /etc/nginx/ssl/direct.crt /etc/nginx/ssl/sylab.crt /etc/nginx/ssl/ai-origin/*; do
  [ -f "$c" ] || continue
  echo "--- $c"
  openssl x509 -in "$c" -noout -subject -ext subjectAltName 2>/dev/null | head -3
done
echo "===== existing 8099 server_names ====="
nginx -T 2>/dev/null | grep -nE "listen .*8099|server_name" | grep -B1 -A0 "" | grep -A1 8099 | head -20
echo "===== current sylab-web vhost ====="
cat /etc/nginx/sites-available/sylab-web 2>/dev/null
