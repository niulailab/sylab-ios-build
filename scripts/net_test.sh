#!/bin/bash
echo "=== IPv4 resolution ==="
docker exec browser-service sh -c 'getent ahostsv4 example.com'
echo "=== curl IPv4 forced ==="
docker exec browser-service sh -c 'curl -4 -s -m 12 -o /dev/null -w "v4 http=%{http_code} time=%{time_total}\n" https://example.com' 2>&1
echo "=== curl IPv6 forced ==="
docker exec browser-service sh -c 'curl -6 -s -m 12 -o /dev/null -w "v6 http=%{http_code} time=%{time_total}\n" https://example.com' 2>&1
echo "=== curl default ==="
docker exec browser-service sh -c 'curl -s -m 12 -o /dev/null -w "default http=%{http_code} time=%{time_total}\n" https://example.com' 2>&1
echo "=== baidu (has v4) ==="
docker exec browser-service sh -c 'getent ahostsv4 www.baidu.com | head -2; curl -4 -s -m 12 -o /dev/null -w "baidu v4 http=%{http_code}\n" https://www.baidu.com' 2>&1
echo "[DONE]"
