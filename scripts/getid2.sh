#!/bin/bash
echo "=== IDENT-DBG last 10m ==="
docker logs tool-proxy --since 10m 2>&1 | grep "IDENT-DBG" | tail -20
echo ""
echo "=== phone schedule hits in nginx last 10m ==="
grep -h "schedule" /var/log/nginx/access.log 2>/dev/null | grep "sylab/" | tail -10
