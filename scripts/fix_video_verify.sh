#!/bin/bash

echo "=== Step 1: 等 coze-server 启动完成 ==="
for i in $(seq 1 12); do
  if docker exec coze-server curl -s --max-time 5 http://localhost:8888/health >/dev/null 2>&1; then
    echo "coze-server is healthy"
    break
  fi
  echo "Waiting... ($i)"
  sleep 5
done

echo
echo "=== Step 2: 查 response schema 的完整定义 ==="
docker exec coze-mysql mysql -uroot -pd3G8JG273iE8C4irRWJX opencoze -N -e "
SELECT tool_name, 
  JSON_KEYS(JSON_EXTRACT(operation, '$.responses.200.content.application/json.schema')) as schema_keys,
  JSON_EXTRACT(operation, '$.responses.200.content.application/json.schema.type') as schema_type
FROM agent_tool_version
WHERE agent_id = 7669580347859795968
AND tool_name IN ('video_generate_v2','video_status_v2');" 2>/dev/null

echo
echo "=== Step 3: 检查旧工具是否需要清理 ==="
docker exec coze-mysql mysql -uroot -pd3G8JG273iE8C4irRWJX opencoze -N -e "
SELECT id, tool_name, sub_url, method
FROM agent_tool_version
WHERE agent_id = 7669580347859795968
AND tool_name IN ('video_generate','video_status');" 2>/dev/null

echo
echo "=== Step 4: 查 video_generate_v2 的完整 operation ==="
docker exec coze-mysql mysql -uroot -pd3G8JG273iE8C4irRWJX opencoze -N -e "
SELECT operation FROM agent_tool_version WHERE tool_name='video_generate_v2' AND agent_id=7669580347859795968;" 2>/dev/null | python3 -m json.tool 2>/dev/null | head -80

echo
echo "=== Step 5: 测试直接调用 video_generate（模拟 AI 调用）==="
USER_ID=$(docker exec coze-mysql mysql -uroot -pd3G8JG273iE8C4irRWJX opencoze -N -e "SELECT user_id FROM user LIMIT 1;" 2>/dev/null | head -1)
echo "User ID: $USER_ID"

# 先 quote
echo "--- quote ---"
curl -s --max-time 15 -X POST "http://127.0.0.1:9092/video/generate" \
  -H "Content-Type: application/json" \
  -H "X-AiPlugin-Connector-Identifier: test" \
  -d "{\"action\":\"quote\",\"prompt\":\"test cat\",\"model\":\"h3-fast\",\"duration\":5,\"user_id\":\"$USER_ID\"}" | python3 -c "import json,sys; d=json.load(sys.stdin); print(json.dumps(d, indent=2, ensure_ascii=False))"

echo
echo "=== Step 6: 查 tool-proxy 日志（确认请求被正确处理）==="
docker logs tool-proxy --since 5m 2>&1 | grep -iE "video" | tail -10

echo "[DONE]"
