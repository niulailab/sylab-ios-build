#!/usr/bin/env bash
exec > /var/www/sylab-ios/verify5_0930.txt 2>&1
set +e
echo "##### 1. 谁引用 tool-proxy 主机名 (compose内)"
grep -n "tool-proxy" /root/coze-studio/docker/docker-compose.yml
echo
echo "##### 2. coze-server 段行号"
grep -n "^  coze-server:\|^  tool-proxy:\|networks:\|extra_hosts:\|ipv4_address:" /root/coze-studio/docker/docker-compose.yml
echo
echo "##### 3. networks 定义段"
awk '/^networks:/{f=1} f{print NR": "$0}' /root/coze-studio/docker/docker-compose.yml | head -30
echo
echo "##### 4. 各运行容器里谁的环境/配置含 tool-proxy"
for c in $(docker ps --format '{{.Names}}'); do
  if docker exec "$c" sh -c 'env | grep -q tool-proxy' 2>/dev/null; then echo "$c -> env含tool-proxy"; fi
done
echo "--- 检查哪些容器能解析(实际调用方)---"
for c in coze-server; do
  echo "[$c] $(docker exec $c getent hosts tool-proxy 2>/dev/null || echo fail)"
done
echo
echo "##### 5. compose 备份现状"
ls -la /root/coze-studio/docker/docker-compose.yml*
