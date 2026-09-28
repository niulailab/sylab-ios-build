#!/bin/bash
# Check how the app authenticates
echo "=== Test auth endpoints ==="
curl -s -X POST "https://direct.symsgf.xyz:8099/api/login" \
  -H "Content-Type: application/json" \
  -d '{"email":"admin@sylab.ai","password":"Sylab2026!"}' | head -c 500
echo ""
echo "---"
curl -s -X POST "https://direct.symsgf.xyz:8099/v1/login" \
  -H "Content-Type: application/json" \
  -d '{"email":"admin@sylab.ai","password":"Sylab2026!"}' | head -c 500
echo ""
echo "---"
# Check how existing test scripts auth
grep -r "token\|login\|auth" /root/coze-studio/tool-proxy/server.py 2>/dev/null | grep -i "endpoint\|path\|route" | head -10
echo "---"
# Check nginx routes
grep -E "location|proxy_pass" /etc/nginx/sites-enabled/* 2>/dev/null | grep -v "#" | head -20
