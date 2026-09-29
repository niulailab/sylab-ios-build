#!/bin/bash

echo "### 1. 验证 MaxStep 200（编译进二进制）###"
# coze-server 二进制路径
docker exec coze-server sh -c 'ls -la /app/bin/ 2>/dev/null; which coze-server 2>/dev/null; ls /app 2>/dev/null' 2>&1 | head -20
echo ""
# strings 搜二进制中的 MaxStep 相关
BIN=$(docker exec coze-server sh -c 'ls /app/bin/* 2>/dev/null | head -1; ls /app/server 2>/dev/null; ls /coze-server 2>/dev/null' 2>&1 | head -1)
echo "binary candidate: $BIN"
docker exec coze-server sh -c "strings $BIN 2>/dev/null | grep -iE 'max.?step|max.?iteration|max.?turn' | head -10" 2>&1

echo ""
echo "### 2. 从实际任务数据验证（最近有没有超过30步的run）###"
docker exec coze-mysql mysql -uroot -p"$(docker exec coze-mysql printenv MYSQL_ROOT_PASSWORD 2>/dev/null)" opencoze -e "
SELECT id, bot_id, status, LEFT(statistics,100) as stats, created_at 
FROM agent_run 
ORDER BY created_at DESC LIMIT 5\G" 2>/dev/null | head -40

echo ""
echo "### 3. tool-proxy 挂载方式（决定测试脚本怎么放）###"
docker inspect tool-proxy --format '{{range .Mounts}}{{.Source}} -> {{.Destination}}{{"\n"}}{{end}}'

echo "[DONE]"
