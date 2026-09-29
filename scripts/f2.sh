#!/bin/bash
echo "===== 运行容器 env/创建时间/image ====="
docker inspect tool-proxy --format 'created={{.Created}} image={{.Config.Image}}'
docker exec tool-proxy printenv | grep -i bocha || echo "(容器内无 BOCHA)"
echo ""
echo "===== server.py 博查/搜索段 2855-2970 ====="
sed -n '2855,2970p' /root/coze-studio/tool-proxy/server.py
echo "[DONE]"
