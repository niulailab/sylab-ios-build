#!/bin/bash
echo "=== sylab-app tabs structure ==="
ls -la /root/sylab-app/app/\(tabs\)/ 2>/dev/null
echo ""
echo "=== app.json name/slug ==="
grep -E '"name"|"slug"|"version"' /root/sylab-app/app.json 2>/dev/null | head
echo ""
echo "=== src/api dir ==="
ls -la /root/sylab-app/src/api/ 2>/dev/null
echo ""
echo "=== how app calls backend: baseURL & identity headers ==="
grep -rnE "x-aiplugin-user-id|x-user-id|baseURL|BASE_URL|9092|/schedule" /root/sylab-app/src/api/ /root/sylab-app/app/ 2>/dev/null | grep -v node_modules | head -40
echo ""
echo "=== nginx: schedule / 9092 routes ==="
grep -nE "9092|schedule|/bigmodel" /etc/nginx/sites-enabled/default | head -20
