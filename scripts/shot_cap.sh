#!/bin/bash
curl -s -m 60 -X POST http://127.0.0.1:9096/browser/screenshot \
 -H 'Content-Type: application/json' \
 -d '{"url":"https://example.com"}' -o /tmp/cap.json
echo "=== pretty ==="
python3 -m json.tool /tmp/cap.json 2>/dev/null || cat /tmp/cap.json
echo ""
echo "=== sanity: does container have outbound net? ==="
docker exec browser-service sh -c 'curl -s -m 10 -o /dev/null -w "example.com http=%{http_code}\n" https://example.com' 2>/dev/null \
 || docker exec browser-service python3 -c "import urllib.request;print('urllib',urllib.request.urlopen('https://example.com',timeout=10).status)" 2>/dev/null
