#!/bin/bash
TP=$(docker ps --format '{{.Names}}'|grep -i tool-proxy|head -1)
echo "=== upstream defs ==="
docker exec "$TP" sh -lc "grep -nE 'ZHIPU_UPSTREAM|UPSTREAM' /app/server.py | head -20"
echo "=== all env (filter) ==="
docker exec "$TP" sh -lc 'env | grep -iE "ZHIPU|UPSTREAM|proxy|bigmodel" '
echo "=== last 60 proxy log lines ==="
docker logs --tail 120 "$TP" 2>&1 | grep -iE 'zhipu|bigmodel' | tail -60
echo DONE
