#!/usr/bin/env bash
set +e
echo "######## A. sites-enabled ########"
ls -la /etc/nginx/sites-enabled/
echo
echo "######## B. which enabled files listen 9091 ########"
for f in /etc/nginx/sites-enabled/*;do
 echo "===== $f ====="
 grep -nE 'listen|server_name' "$f" | head
done
echo
echo "######## C. test memory search via 127.0.0.1:8900 ########"
curl -s -X POST "http://127.0.0.1:8900/memory/search" \
 -H 'Content-Type: application/json' \
 -d '{"agent_id":"sylab-ai","query":"skill","limit":2}' | head -c 600
echo
echo
echo "######## D. server block closing context of the 9091 sylab file ########"
F=$(grep -rln 'listen 9091' /etc/nginx/sites-enabled/ 2>/dev/null | head -1)
echo "FILE=$F"
echo "total lines: $(wc -l < "$F" 2>/dev/null)"
echo "--- last 30 lines ---"
tail -30 "$F"
echo "FIND_CONF_DONE"
