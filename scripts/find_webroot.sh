#!/bin/bash
set +e
echo "===== server blocks mapping (s.symsgf / chat-sdk) ====="
nginx -T 2>/dev/null | awk '
  /server[ ]*\{/ {inserver=1}
  inserver && /server_name|listen|root |index |location = \/ {print NR": "$0}
  /\}/ {if(inserver) inserver=0}
' | grep -B3 -A1 -E "s\.symsgf|chat-sdk" | head -60
echo "===== grep -A context for s.symsgf ====="
nginx -T 2>/dev/null | grep -n -A25 "server_name s\.symsgf" | grep -E "server_name|listen|root|index|location" | head -30
echo "===== dirs ====="
for d in /var/www/chat-sdk /var/www/sylab-web /var/www/html; do
  [ -d "$d" ] && { echo "--- $d"; ls -la "$d" | head -12; }
done
