#!/bin/bash
CS=$(docker ps --format '{{.Names}}' | grep -Ei 'coze-server|coze_server' | head -1)
echo "server=$CS"
docker inspect "$CS" --format 'image: {{.Config.Image}}{{println}}workdir: {{.Config.WorkingDir}}{{println}}entry: {{json .Config.Entrypoint}}{{println}}cmd: {{json .Config.Cmd}}'
docker exec "$CS" sh -lc 'ls -la /app 2>/dev/null | head -30 || ls / | head'
echo DONE
