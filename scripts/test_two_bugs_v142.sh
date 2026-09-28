#!/bin/bash
set -uo pipefail
echo "=== restart tool-proxy to apply clean ==="
docker restart tool-proxy >/dev/null
sleep 6
docker logs tool-proxy --since 30s 2>&1 | grep -c IDENT-DBG | sed 's/^/IDENT-DBG now: /'

echo ""
echo "=== BUG1: browser-service screenshot test (9096) ==="
# discover endpoints
docker ps --format '{{.Names}}' | grep browser
echo "--- probe browser-service root ---"
curl -s -m 15 http://127.0.0.1:9096/ -o /dev/null -w "root http=%{http_code}\n"
# try common screenshot endpoint shapes
echo "--- try /screenshot baidu ---"
curl -s -m 40 -X POST http://127.0.0.1:9096/screenshot \
 -H 'Content-Type: application/json' \
 -d '{"url":"https://www.baidu.com"}' | head -c 400
echo ""

echo ""
echo "=== BUG2: minio reachable + buckets ==="
echo "--- minio from host ---"
curl -s -m 10 http://127.0.0.1:9000/minio/health/live -o /dev/null -w "minio health http=%{http_code}\n"
echo "--- list buckets via mc inside container? ---"
docker exec coze-minio sh -c 'ls /data 2>/dev/null | head; echo "---"; mc ls local/ 2>/dev/null | head' 2>/dev/null | head -20
echo ""
echo "--- find bucket dirs on minio volume ---"
docker exec coze-minio sh -c 'find /data -maxdepth 2 -type d 2>/dev/null' | head -30
echo "[DONE]"
