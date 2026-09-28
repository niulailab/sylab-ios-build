#!/bin/bash
echo "=== profile menu groups definition ==="
sed -n '1,45p' /root/sylab-app/app/\(tabs\)/profile.tsx
echo ""
echo "=== what listens on 8099 host ==="
ss -ltnp | grep 8099
grep -rnE "8099" /etc/nginx/sites-enabled/default | head
echo ""
echo "=== test /schedule/list via local 9092 with identity header ==="
curl -s -m 10 -X POST http://127.0.0.1:9092/schedule/list \
 -H "Content-Type: application/json" \
 -H "x-aiplugin-user-id: 7666848996043784192" -d '{}'
echo ""
echo "=== same via public entry 8099 ==="
curl -s -m 15 -k -X POST https://direct.symsgf.xyz:8099/schedule/list \
 -H "Content-Type: application/json" \
 -H "x-aiplugin-user-id: 7666848996043784192" -d '{}'
