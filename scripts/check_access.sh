#!/bin/bash
echo "=== nginx access logs: schedule hits last 15 min ==="
for L in /var/log/nginx/access.log /var/log/nginx/access.log.1; do
 [ -f "$L" ] && grep -h "schedule" "$L" 2>/dev/null | tail -20
done
echo ""
echo "=== any recent POST from non-local (phones) last 200 lines ==="
tail -200 /var/log/nginx/access.log 2>/dev/null | grep -E "POST" | tail -15
echo ""
echo "=== tool-proxy wider window 30m ==="
docker logs tool-proxy --since 30m 2>&1 | grep -E "IDENT-DBG|/schedule/list" | tail -20
echo "[DONE]"
