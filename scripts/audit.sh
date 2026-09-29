#!/bin/bash
echo "===== 当前时间 ====="; date '+%F %T'

echo "===== 1. tool-proxy server.py 真实状态 ====="
ls -la /root/coze-studio/tool-proxy/server.py
md5sum /root/coze-studio/tool-proxy/server.py
wc -l /root/coze-studio/tool-proxy/server.py
echo "--- 含哪些关键标记 ---"
for kw in adaptive _watch have_vis _iter_tail reasoning_effort "inject=low" zhipu_proxy strip "强制" medium; do
  n=$(grep -c "$kw" /root/coze-studio/tool-proxy/server.py 2>/dev/null)
  echo "  [$kw] 出现 $n 次"
done
echo "--- bigmodel 路由当前实际代码 ---"
grep -nE "bigmodel/v1|reasoning_effort|payload\[|strip|thinking" /root/coze-studio/tool-proxy/server.py | head -20

echo "===== 2. server.py 备份版本清单（按时间）====="
ls -lat /root/backup_*/server.py.bak /root/coze-studio/tool-proxy/server.py.bak* 2>/dev/null | head -12

echo "===== 3. 100015 当前 connection ====="
MP=$(docker exec coze-mysql printenv MYSQL_ROOT_PASSWORD)
docker exec coze-mysql mysql -uroot -p"$MP" opencoze -N -e "SELECT connection FROM model_instance WHERE id=100015;" 2>/dev/null

echo "===== 4. 服务状态与启动时间 ====="
echo "--- code-exec(systemd) ---"; systemctl is-active code-exec.service; ps -ef|grep code_exec_server|grep -v grep|awk '{print "node pid="$2" 启动(STIME列)="$5}'
echo "--- 容器（含启动时长）---"
docker ps --format '{{.Names}}\t{{.Status}}\t{{.CreatedAt}}' | grep -E "tool-proxy|coze-server"

echo "===== 5. code_exec_server.js 熔断是否还在 ====="
grep -c "SHELL SPIN CIRCUIT BREAKER" /root/code_exec_server.js 2>/dev/null
echo "[AUDIT DONE]"
