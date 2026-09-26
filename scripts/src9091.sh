#!/bin/bash
echo "===== 9091 default server: root + location / ====="
nginx -T 2>/dev/null | awk '/listen .*9091/{f=1} f{print} f&&/^    }/{exit}' | grep -nE "listen|server_name|root |index |location |alias |proxy_pass|try_files" | head -40
echo
echo "===== full blocks referencing a web root ====="
nginx -T 2>/dev/null | grep -nE "root .*(web|dist|build|sylab)" | head -20
echo
echo "===== what does local 9091 / return ====="
curl -s -m 8 -D /tmp/h9.txt "http://127.0.0.1:9091/" -o /tmp/idx9.html
grep -iE "^HTTP|content-type" /tmp/h9.txt
echo "bytes=$(wc -c </tmp/idx9.html)"
grep -oE 'entry-[A-Za-z0-9]+\.js' /tmp/idx9.html | head
head -c 200 /tmp/idx9.html; echo
echo "===== compare to web-build ====="
grep -oE 'entry-[A-Za-z0-9]+\.js' /root/sylab-app/web-build/index.html | head
