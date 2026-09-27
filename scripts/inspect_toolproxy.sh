#!/bin/bash
echo "=== tool-proxy env ==="
docker inspect tool-proxy --format '{{range .Config.Env}}{{println .}}{{end}}' | grep -v '^PATH='
echo "=== tool-proxy cmd/entrypoint ==="
docker inspect tool-proxy --format 'CMD: {{json .Config.Cmd}}{{println}}ENTRY: {{json .Config.Entrypoint}}'
echo "=== try exec ls ==="
docker exec tool-proxy sh -lc 'ls /app 2>/dev/null || ls / 2>/dev/null' | head
echo DONE
