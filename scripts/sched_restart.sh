#!/usr/bin/env bash
set -e
echo "=== 重启 scheduler-service ==="
docker restart sylab-scheduler-service
sleep 3
docker ps -a --filter name=scheduler --no-trunc
echo ""
echo "=== scheduler logs ==="
docker logs --tail 50 sylab-scheduler-service 2>&1 | tail -50
