#!/bin/bash
echo "=== browser-service logs last 30 min ==="
docker logs browser-service --since 30m 2>&1 | tail -40
echo ""
echo "=== browser-service source layout ==="
docker inspect browser-service --format '{{range .Mounts}}{{.Source}} -> {{.Destination}}{{println}}{{end}}'
docker inspect browser-service --format '{{json .Config.Cmd}} {{json .Config.Entrypoint}}'
