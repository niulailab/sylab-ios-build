#!/usr/bin/env bash
exec > /var/www/sylab-ios/verify2_0930.txt 2>&1
set +e
echo "##### 1. tool-proxy 容器/网络"
docker ps -a --filter name=tool-proxy --format '{{.Names}} | {{.Status}} | {{.Image}}'
docker inspect tool-proxy --format 'Networks: {{range $k,$v := .NetworkSettings.Networks}}{{$k}} {{end}}'
echo
echo "##### 2. coze-server 能否解析 tool-proxy"
docker exec coze-server getent hosts tool-proxy 2>&1 || echo "getent fail"
echo
echo "##### 3. 所有含 schedule/scheduled 的表"
MP=$(docker exec coze-mysql printenv MYSQL_ROOT_PASSWORD)
docker exec coze-mysql mysql -uroot -p"$MP" -N -e "SELECT table_schema,table_name FROM information_schema.tables WHERE table_name LIKE '%sched%';" 2>&1
echo
echo "##### 4. tool-proxy /run_command 实测"
curl -s -m 20 -X POST http://tool-proxy:9092/run_command -H 'Content-Type: application/json' -d '{"command":"echo DNS_OK; date +%T"}' 2>&1 | head -5
echo
echo "##### 5. 近24h coze-server 出现 misbehaving 的次数"
docker logs --since 24h coze-server 2>&1 | grep -c "misbehaving"
