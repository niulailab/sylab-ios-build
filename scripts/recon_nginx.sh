#!/usr/bin/env bash
set +e
echo "######## A. nginx -T : server blocks listening on 8099 / 9091 / 80 ########"
nginx -T 2>/dev/null | grep -nE 'listen|server_name|location|proxy_pass' | grep -B2 -A0 -E '8099|9091' | head -40
echo
echo "######## B. find conf files mentioning 8099 ########"
grep -rlnE '8099' /etc/nginx/ 2>/dev/null
echo
echo "######## C. for each such file: show server_name + locations (bounded) ########"
for f in $(grep -rlnE '8099' /etc/nginx/ 2>/dev/null);do
 echo "===== $f ====="
 grep -nE 'listen|server_name|location |proxy_pass|root ' "$f" | head -40
done
echo
echo "######## D. who serves /user-upload (process) ########"
ss -ltnp 2>/dev/null | grep -vE ':8099|:80 |:9091' | grep -E 'python|node|uvicorn|gunicorn' | head
ps aux | grep -Ei 'file_service|uvicorn|gunicorn' | grep -v grep | head
echo
echo "######## E. /etc/nginx full conf tree ########"
find /etc/nginx -maxdepth 2 -type f | head -40
echo
echo "RECON_NGINX_DONE"
