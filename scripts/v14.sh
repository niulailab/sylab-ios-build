#!/bin/bash
echo "===== 1) tool-proxy /browser/content 原始返回(简站example) ====="
curl -s -m 40 -X POST http://localhost:9092/browser/content -H 'Content-Type: application/json' \
 -d '{"url":"https://example.com"}' -w "\n[http=%{http_code}]\n" | head -c 1200
echo ""
echo "===== 2) 直接打 browser-service (绕过tool-proxy) ====="
docker ps --format '{{.Names}}' | grep -i browser
BS=$(docker ps --format '{{.Names}}' | grep -i browser | head -1)
echo "container=$BS"
curl -s -m 40 -X POST "http://localhost:9096/browser/content" -H 'Content-Type: application/json' \
 -d '{"url":"https://example.com"}' -w "\n[http=%{http_code}]\n" 2>&1 | head -c 800
echo ""
echo "===== 3) browser-service 最近日志(错误/重启/超时) ====="
docker logs --tail 40 "$BS" 2>&1 | tail -40
echo "[DONE]"
