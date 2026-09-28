#!/bin/bash
echo "=== container status ==="
docker ps --format '{{.Names}}\t{{.Status}}' | grep browser
echo "=== direct call verbose timing ==="
curl -s -m 60 -X POST http://127.0.0.1:9096/browser/screenshot \
 -H 'Content-Type: application/json' \
 -d '{"url":"https://example.com"}' \
 -w "\n[http=%{http_code} time=%{time_total}s size=%{size_download}]\n"
echo "=== logs right after ==="
docker logs browser-service --since 2m 2>&1 | tail -20
