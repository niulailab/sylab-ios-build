#!/bin/bash
echo "=== IDENT-DBG lines last 5m ==="
docker logs tool-proxy --since 5m 2>&1 | grep "IDENT-DBG" | tail -20
echo ""
echo "=== all schedule/list hits last 5m ==="
docker logs tool-proxy --since 5m 2>&1 | grep -E "POST /schedule/list" | tail -20
