#!/bin/bash
echo "=== coze-server status ==="
docker ps --format '{{.Names}}\t{{.Status}}' | grep -E 'coze-server|tool-proxy|mysql|redis'
echo "=== coze-server recent logs ==="
docker logs --tail 60 coze-server 2>&1 | grep -iE 'error|fail|panic|model|chat|tool-proxy|refus|500|context|prompt' | tail -40
echo "=== tool-proxy recent ==="
docker logs --tail 30 tool-proxy 2>&1 | tail -30
echo DONE
