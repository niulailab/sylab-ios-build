#!/bin/bash

echo "========== sylab 补丁全面审计 =========="
echo ""

echo "### 1. tool-proxy data字段string修复（刚做的）###"
cd /root/coze-studio/tool-proxy
COUNT=$(awk 'NR>=5432 && NR<=5590 && /"data":json\.dumps/' server.py | wc -l)
REMAIN=$(awk 'NR>=5432 && NR<=5590 && /"data":\{/ && !/json\.dumps/' server.py | wc -l)
echo "  v2函数 data:json.dumps 数量: $COUNT (期望8)"
echo "  残留 data:{ 对象: $REMAIN (期望0)"
docker ps --format '{{.Names}} {{.Status}}' | grep tool-proxy

echo ""
echo "### 2. MaxStep 30→200 ###"
grep -rn "MaxStep\|max_step\|MaxIteration\|200" /root/coze-studio/docker/ 2>/dev/null | grep -iE "step|iter" | head -5
# Check in env/config
grep -rn "MAX_STEP\|MAX_ITER\|maxStep" /root/coze-studio/.env* /root/coze-studio/docker/.env* 2>/dev/null | head -5

echo ""
echo "### 3. 消息分页 PageNum/PageSize ###"
grep -rn "PageNum\|PageSize\|page_num\|page_size" /root/coze-studio/tool-proxy/server.py | head -5

echo ""
echo "### 4. coderunner 隔离容器 ###"
docker ps -a --format '{{.Names}} {{.Image}} {{.Status}}' | grep -i "coderunner\|runner"
# Check tool-proxy for execute_code implementation
grep -n "coderunner\|execute_code\|run_command" /root/coze-studio/tool-proxy/server.py | head -10

echo ""
echo "### 5. web-search 博查优先 ###"
grep -n "bocha\|博查\|360" /root/coze-studio/tool-proxy/server.py | head -10

echo ""
echo "### 6. upload 显式base64 ###"
grep -n "base64\|upload" /root/coze-studio/tool-proxy/server.py | grep -i upload | head -10

echo ""
echo "### 7. MySQL 自建表HCL同步 ###"
grep -n "token_accounts\|rh_tasks\|video" /root/coze-studio/docker/atlas/opencoze_latest_schema.hcl 2>/dev/null | head -10
ls -la /root/coze-studio/docker/atlas/ 2>/dev/null

echo ""
echo "### 8. 所有容器运行状态 ###"
docker ps --format 'table {{.Names}}\t{{.Image}}\t{{.Status}}' | head -30

echo ""
echo "### 9. coze-server 关键编译特性 ###"
docker logs coze-server --since 5m 2>&1 | grep -iE "maxstep\|max_step\|version\|build" | head -5
# Check coze-server image creation date vs patches
docker inspect coze-server --format '{{.Config.Image}} created={{.Created}}' 2>/dev/null

echo ""
echo "### 10. tool-proxy 文件修改时间 ###"
ls -la /root/coze-studio/tool-proxy/server.py
echo "备份文件:"
ls -la /root/coze-studio/tool-proxy/server.py.bak.* 2>/dev/null | tail -5

echo "[DONE]"
