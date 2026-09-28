#!/bin/bash
echo "=== direct-symsgf conf ==="
cat /etc/nginx/sites-enabled/direct-symsgf
echo ""
echo "=== test /schedule/list WITH correct SNI ==="
curl -s -m 15 -k --resolve direct.symsgf.xyz:8099:127.0.0.1 \
 -X POST https://direct.symsgf.xyz:8099/schedule/list \
 -H "Content-Type: application/json" \
 -H "x-aiplugin-user-id: 7666848996043784192" -d '{}'
echo ""
echo "=== via 443 ==="
curl -s -m 15 -k --resolve direct.symsgf.xyz:443:127.0.0.1 \
 -X POST https://direct.symsgf.xyz/schedule/list \
 -H "Content-Type: application/json" \
 -H "x-aiplugin-user-id: 7666848996043784192" -d '{}'
