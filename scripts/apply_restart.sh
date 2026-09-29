#!/bin/bash
echo "### 重启前（确认node熔断服务不动）###"
ps -ef | grep code_exec_server | grep -v grep | awk '{print "node pid="$2}'
systemctl is-active code-exec.service

echo "### 重启 coze-server（清模型缓存，让flash直连生效）###"
docker restart coze-server >/dev/null; sleep 12
docker ps --format '{{.Names}}\t{{.Status}}' | grep coze-server

echo "### 重启 tool-proxy（透传生效）###"
docker restart tool-proxy >/dev/null; sleep 8
docker ps --format '{{.Names}}\t{{.Status}}' | grep tool-proxy

echo "### 体检 ###"
docker exec coze-server ps -ef 2>/dev/null | grep -v "ps -ef" | grep opencoze && echo "coze-server 主进程在"
docker logs coze-server --since 30s 2>&1 | grep -iE "panic|fatal|error" | head -5 || true
echo "--- 端口 ---"
curl -s -o /dev/null -w "9097 熔断服务:%{http_code}\n" -X POST http://127.0.0.1:9097/execute -H 'Content-Type: application/json' -d '{"code":"echo ok","language":"shell"}'
curl -s -o /dev/null -w "9092 tool-proxy:%{http_code}(404正常)\n" http://127.0.0.1:9092/
echo "--- 确认DB最终配置 ---"
MP=$(docker exec coze-mysql printenv MYSQL_ROOT_PASSWORD)
docker exec coze-mysql mysql -uroot -p"$MP" opencoze -N -e "SELECT connection FROM model_instance WHERE id=100015;" 2>/dev/null | python3 -c "import json,sys;b=json.load(sys.stdin)['base_conn_info'];print('model=',b['model']);print('base_url=',b['base_url']);print('thinking_type=',b['thinking_type'])"
echo "[DONE]"
