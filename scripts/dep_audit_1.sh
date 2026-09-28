#!/bin/bash
echo "=== 1) any reference to 8910 / coze-automation across nginx & code ==="
grep -rnE "8910|coze-automation|automation-service" /etc/nginx/sites-enabled/ 2>/dev/null | grep -v "\.bak" 
grep -rlnE "8910|coze-automation" /root --include="*.py" --include="*.js" --include="*.ts" --include="*.sh" 2>/dev/null | grep -v node_modules | grep -v "automation-service/" | head
echo ""
echo "=== 2) automation container: who talks to it? check its networks + external links ==="
docker inspect coze-automation-service --format '{{range $k,$v := .NetworkSettings.Networks}}net={{$k}} ip={{$v.IPAddress}}{{"\n"}}{{end}}'
docker inspect coze-automation-service --format 'links={{.HostConfig.Links}}'
echo ""
echo "=== 3) active TCP conns into 8910 (last) ==="
ss -tnp 2>/dev/null | grep ':8910' | head
echo ""
echo "=== 4) scheduler-service referenced anywhere (image/containers/docker-compose) ==="
grep -rnE "scheduler-service" /root/coze-studio/docker/ 2>/dev/null | grep -v "\.bak" | head
docker ps -a --format '{{.Names}} {{.Image}}' | grep -i sched
echo ""
echo "=== 5) does automation serve traffic right now? recent access ==="
docker logs coze-automation-service --tail 15 2>&1 | tail -15
