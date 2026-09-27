#!/bin/bash
echo "=== proxy inject block ==="
grep -n "reasoning_effort\|enable_thinking\|thinking\|payload\[" /root/coze-studio/tool-proxy/server.py | head -40
echo "=== proxy container mount & uptime ==="
docker inspect tool-proxy --format '{{range .Mounts}}{{.Source}} -> {{.Destination}}{{println}}{{end}}status={{.State.Status}} started={{.State.StartedAt}}'
echo "=== proxy recent logs ==="
docker logs --tail 25 tool-proxy 2>&1 | tail -25
echo DONE
