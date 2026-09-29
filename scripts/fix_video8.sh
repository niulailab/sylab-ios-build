#!/bin/bash
echo "=== 1) 查 Coze 框架最近的 tool call 日志（找 video_generate）==="
docker logs coze-server --since 30m 2>&1 | grep -A 5 -B 2 "video_generate" | tail -60

echo
echo "=== 2) 查 tool-proxy 最近的 video 请求和响应 ==="
docker logs tool-proxy --since 30m 2>&1 | grep -E "POST /video/generate|GET /video/status" | tail -20

echo
echo "=== 3) 直接调用 video_generate_v2 测试（用真实 user_id）==="
# 先查一个真实的 user_id
docker exec coze-mysql mysql -uroot -pd3G8JG273iE8C4irRWJX opencoze -N -e "
SELECT user_id FROM user LIMIT 1;" 2>/dev/null

# 用找到的 user_id 调用
USER_ID=$(docker exec coze-mysql mysql -uroot -pd3G8JG273iE8C4irRWJX opencoze -N -e "SELECT user_id FROM user LIMIT 1;" 2>/dev/null | head -1)
echo "Using user_id: $USER_ID"

curl -s --max-time 15 -X POST "http://127.0.0.1:9092/video/generate" \
  -H "Content-Type: application/json" \
  -H "X-AiPlugin-Connector-Identifier: test" \
  -d "{
    \"action\": \"generate\",
    \"prompt\": \"a cute cat running in the park\",
    \"model\": \"h3-fast\",
    \"duration\": 5,
    \"user_id\": \"$USER_ID\"
  }" | python3 -m json.tool 2>/dev/null || echo "Response parse failed"

echo
echo "[DONE]"
