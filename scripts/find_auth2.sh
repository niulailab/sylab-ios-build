#!/bin/bash
# Find how the app logs in - check the actual frontend source or API
echo "=== Find login/session endpoints ==="
# Check coze-server routes
docker exec coze-server find /app -name "*.go" -path "*auth*" -o -name "*.go" -path "*login*" -o -name "*.go" -path "*session*" 2>/dev/null | head -20

echo ""
echo "=== Try passport/login endpoints ==="
curl -s -X POST "https://direct.symsgf.xyz:8099/api/passport/login" \
  -H "Content-Type: application/json" \
  -d '{"email":"admin@sylab.ai","password":"Sylab2026!"}' -c /tmp/cookies.txt | head -c 500
echo ""
cat /tmp/cookies.txt 2>/dev/null | grep session
echo "---"

# Try with username
curl -s -X POST "https://direct.symsgf.xyz:8099/api/passport/login" \
  -H "Content-Type: application/json" \
  -d '{"name":"admin@sylab.ai","password":"Sylab2026!"}' -c /tmp/cookies2.txt | head -c 500
echo ""
cat /tmp/cookies2.txt 2>/dev/null | grep session
