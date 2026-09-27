#!/bin/bash
RID=$(docker ps --format '{{.Names}}' | grep -Ei 'redis' | head -1)
echo "redis=$RID"
docker exec "$RID" sh -lc 'redis-cli --scan --pattern "*7669580347859795968*" | head -40'
echo "=== generic bot keys ==="
docker exec "$RID" sh -lc 'redis-cli --scan --pattern "*single_agent*" | head -20'
docker exec "$RID" sh -lc 'redis-cli --scan --pattern "*bot*" | head -30'
echo DONE
