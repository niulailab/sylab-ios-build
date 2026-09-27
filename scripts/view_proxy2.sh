#!/bin/bash
TP=$(docker ps --format '{{.Names}}'|grep -i tool-proxy|head -1)
echo "container=$TP"
echo "=== route + func (2060-2160) ==="
docker exec "$TP" sh -lc "sed -n '2060,2160p' /app/server.py"
echo "=== mounts ==="
docker inspect "$TP" --format '{{range .Mounts}}{{.Source}} -> {{.Destination}} ({{.Mode}}){{println}}{{end}}'
echo "=== restart policy / image ==="
docker inspect "$TP" --format 'restart={{.HostConfig.RestartPolicy.Name}} image={{.Config.Image}} workdir={{index .Config.Labels "com.docker.compose.project.working_dir"}} cfg={{index .Config.Labels "com.docker.compose.project.config_files"}}'
echo "=== env upstream ==="
docker exec "$TP" sh -lc 'env | grep -iE "ZHIPU|BIGMODEL|UPSTREAM"'
echo DONE
