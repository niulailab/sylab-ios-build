#!/bin/bash
echo "=== nvidia-smi host ==="
nvidia-smi --query-gpu=name,memory.total,memory.used --format=csv 2>/dev/null || echo "no host nvidia-smi"
echo "=== GPU containers ==="
docker ps --format '{{.Names}}' | while read n; do
 docker inspect "$n" --format '{{.HostConfig.DeviceRequests}}' 2>/dev/null | grep -q nvidia && echo "$n uses GPU"
done
echo "=== CPU/MEM ==="
nproc; free -g | head -2
echo "=== disk ==="
df -h / /root 2>/dev/null | head -4
echo DONE
