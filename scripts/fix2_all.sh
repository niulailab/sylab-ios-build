#!/usr/bin/env bash
exec > /var/www/sylab-ios/fix2_0930.txt 2>&1
set +e
cd /root/coze-studio/docker || exit 1
echo "##### 重建前状态"
docker ps --format '{{.Names}} {{.Status}}' | grep -E "coze-server|tool-proxy"

echo
echo "##### up -d tool-proxy (先固定IP)"
docker compose up -d tool-proxy 2>&1
sleep 8

echo "##### up -d coze-server"
docker compose up -d coze-server 2>&1
sleep 20

echo
echo "##### 重建后容器状态"
docker ps --format '{{.Names}} | {{.Status}} | {{.Image}}' | grep -E "coze-server|tool-proxy"
echo
echo "##### tool-proxy 实际IP"
docker inspect tool-proxy --format '{{range $k,$v := .NetworkSettings.Networks}}{{$k}}={{$v.IPAddress}}{{end}}'
echo "##### coze-server extra_hosts"
docker inspect coze-server --format '{{json .HostConfig.ExtraHosts}}'
echo
echo "##### coze-server /etc/hosts 中 tool-proxy"
docker exec coze-server grep -i tool /etc/hosts || echo "MISSING"
