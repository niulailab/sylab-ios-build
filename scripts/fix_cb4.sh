#!/bin/bash
echo "=== 1) 二进制字符串落盘后精确搜 video 路由 ==="
docker exec coze-server bash -c "strings -n 6 /app/opencoze > /tmp/oc.txt 2>/dev/null; wc -l /tmp/oc.txt"
echo "--- 所有含 video 的路径 ---"
docker exec coze-server bash -c "grep -nE '/video|video/callback|api/v1/video' /tmp/oc.txt | head -30"
echo
echo "=== 2) callback 周边可能的 header 校验关键词 ==="
docker exec coze-server bash -c "grep -niE 'X-(Callback|Internal|Video|Api|Token|Auth)|callback[_-]?(key|secret|token)' /tmp/oc.txt | sort -u | head -25"
echo
echo "=== 3) verbose 裸调 callback（确认可达+完整响应）==="
curl -sv --max-time 12 -X POST "http://coze-server:8888/api/v1/video/callback" \
  -H "Content-Type: application/json" -d '{"task_id":"probe","status":"completed"}' 2>&1 | grep -vE "^\* (TLSv|SSL|CAfile|CApath)" | tail -30
echo
echo "=== 4) .env 全部配置项名称（值隐藏）==="
docker exec coze-server bash -c "sed 's/=.*/=<hidden>/' /app/.env" | head -60
echo "[DONE]"
