#!/bin/bash
echo "=== automation container config ==="
docker inspect coze-automation-service --format '{{.Config.Image}}' 2>/dev/null
docker inspect coze-automation-service --format '{{range .Mounts}}{{.Source}} -> {{.Destination}}{{"\n"}}{{end}}' 2>/dev/null
echo "--- env (filtered) ---"
docker inspect coze-automation-service --format '{{range .Config.Env}}{{println .}}{{end}}' 2>/dev/null | grep -iE "PAT|KEY|URL|INTERNAL|REDIS|MYSQL|FIRE|HOST" | head -30

echo ""
echo "=== main.py ==="
cat /root/coze-studio/automation-service/main.py
