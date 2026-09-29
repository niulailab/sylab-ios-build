#!/bin/bash
echo "### 重启前状态 ###"
ps -ef | grep code_exec_server | grep -v grep | awk '{print $2}'

echo "### 1. 重启 code-exec (node+熔断) ###"
systemctl restart code-exec.service
sleep 6
systemctl is-active code-exec.service
ps -ef | grep code_exec_server | grep -v grep

echo "### 2. 重启 tool-proxy ###"
docker restart tool-proxy >/dev/null
sleep 8
docker ps --format '{{.Names}}\t{{.Status}}' | grep tool-proxy

echo "### 3. 重启 coze-server (清模型缓存) ###"
docker restart coze-server >/dev/null
sleep 12
docker ps --format '{{.Names}}\t{{.Status}}' | grep coze-server

echo "### 存活验证 ###"
curl -s -o /dev/null -w "9097 code-exec HTTP:%{http_code}\n" -X POST http://127.0.0.1:9097/execute -H 'Content-Type: application/json' -d '{"code":"echo hi","language":"shell"}'
curl -s -o /dev/null -w "9092 tool-proxy HTTP:%{http_code}\n" http://127.0.0.1:9092/
docker exec coze-server sh -c 'curl -s -o /dev/null -w "coze-server internal HTTP:%{http_code}\n" http://127.0.0.1:8888/ 2>/dev/null || echo "internal curl n/a"'
echo "[DONE]"
