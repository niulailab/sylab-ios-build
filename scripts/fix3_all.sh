#!/usr/bin/env bash
exec > /var/www/sylab-ios/fix3_0930.txt 2>&1
set +e
echo "##### 关键容器状态"
docker ps --format '{{.Names}} | {{.Status}}' | grep -E "coze-server|tool-proxy|coze-mysql|coze-redis|coze-etcd|coze-elasticsearch|coze-milvus"
echo
echo "##### tool-proxy IP (应为 .10)"
docker inspect tool-proxy --format '{{range $k,$v := .NetworkSettings.Networks}}{{$k}}={{$v.IPAddress}} {{end}}'
echo "##### coze-server extra_hosts"
docker inspect coze-server --format '{{json .HostConfig.ExtraHosts}}'
echo "##### coze-server /etc/hosts"
docker exec coze-server grep -i tool /etc/hosts || echo MISSING
echo
echo "##### 直连测试: 绕过DNS, getent + curl tool-proxy"
docker exec coze-server getent hosts tool-proxy
sleep 3
docker exec coze-server sh -c 'curl -s -m 15 -X POST http://tool-proxy:9092/run_command -H "Content-Type: application/json" -d "{\"command\":\"echo STATIC_OK; date +%T\"}"'
echo
echo "##### coze-server 进程/健康"
docker exec coze-server sh -c 'ps aux | grep -v grep | grep opencoze | head -1' || true
