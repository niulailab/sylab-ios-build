#!/bin/bash
SC=$(docker ps --format '{{.Names}}'|grep -iE 'coze-server|coze-studio'|head -1)
echo "server container: $SC"
echo "=== grep table refs in binary ==="
docker exec "$SC" sh -lc "strings /app/opencoze 2>/dev/null | grep -iE 'single_agent_(publish|version|draft)' | sort -u | head -40"
echo "=== redis keys for bot ==="
RC=$(docker ps --format '{{.Names}}'|grep -i redis|head -1)
echo "redis: $RC"
docker exec "$RC" sh -lc 'redis-cli --no-auth-warning -a "$REDIS_PASSWORD" --scan --pattern "*7669580347859795968*" 2>/dev/null | head -40' || echo "no cli/auth"
docker exec "$RC" sh -lc 'redis-cli --no-auth-warning -a "$REDIS_PASSWORD" --scan --pattern "*agent*" 2>/dev/null | head -40' || echo "scan2 fail"
echo DONE
