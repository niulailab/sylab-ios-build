#!/bin/bash
echo "===== restart coze-server ====="
docker restart coze-server
sleep 20
docker ps --format '{{.Names}}\t{{.Status}}' | grep coze-server
docker inspect coze-server --format 'started={{.State.StartedAt}} status={{.State.Status}}'
echo "now=$(date '+%F %T')"
echo "[DONE]"
