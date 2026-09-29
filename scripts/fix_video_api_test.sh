#!/bin/bash

echo "=== Step 1: 查 tool-proxy 最近日志（看 AI 调用时传了什么）==="
docker logs tool-proxy --since 5m 2>&1 | grep -iE "video|tool" | tail -30

echo
echo "=== Step 2: 直接测试 tool-proxy /video/generate 端点（模拟 AI 调用）==="
echo "--- Test A: quote 请求 ---"
curl -s -X POST http://localhost:5435/video/generate \
  -H "Content-Type: application/json" \
  -d '{"action":"quote","duration":5,"prompt":"猫咪"}' | python3 -m json.tool 2>/dev/null || echo "JSON parse failed"

echo
echo "--- Test B: generate 请求（用 app_user 积分账户）---"
curl -s -X POST http://localhost:5435/video/generate \
  -H "Content-Type: application/json" \
  -H "X-User-Id: app_user" \
  -d '{"action":"generate","duration":5,"prompt":"猫咪在玩耍"}' | python3 -m json.tool 2>/dev/null || echo "JSON parse failed"

echo
echo "=== Step 3: 查 Coze 框架最近工具调用日志 ==="
docker logs coze-server --since 5m 2>&1 | grep -iE "video_generate|tool_call|spawn_tool" | grep -vE "grpc|health|register|Method=" | tail -30

echo
echo "=== Step 4: 查 agent 表（找 sylab bot 配置）==="
docker exec coze-mysql mysql -uroot -pd3G8JG273iE8C4irRWJX opencoze -N -e "
SELECT id, name, COALESCE(description,'') FROM agent WHERE id = 7669580347859795968;" 2>/dev/null

echo
echo "=== Step 5: 查 conversation 表（找最近的对话）==="
docker exec coze-mysql mysql -uroot -pd3G8JG273iE8C4irRWJX opencoze -N -e "
SELECT id, bot_id, created_at FROM conversation WHERE bot_id = 7669580347859795968 ORDER BY created_at DESC LIMIT 3;" 2>/dev/null

echo
echo "=== Step 6: 用 Coze 内部 API 触发一次工具调用 ==="
# 获取最近的 conversation_id
CONV_ID=$(docker exec coze-mysql mysql -uroot -pd3G8JG273iE8C4irRWJX opencoze -N -e "
SELECT id FROM conversation WHERE bot_id = 7669580347859795968 ORDER BY created_at DESC LIMIT 1;" 2>/dev/null | tr -d '[:space:]')
echo "Using conversation_id: $CONV_ID"

# 调用 Coze Server 的 chat API
echo "--- Calling Coze chat API ---"
curl -s -X POST http://localhost:8888/api/v3/chat \
  -H "Content-Type: application/json" \
  -d "{
    \"bot_id\": \"7669580347859795968\",
    \"user_id\": \"app_user\",
    \"additional_messages\": [
      {
        \"role\": \"user\",
        \"content\": \"帮我报价一个5秒的猫咪视频\",
        \"content_type\": \"text\"
      }
    ]
  }" | python3 -m json.tool 2>/dev/null | head -80

echo "[DONE]"
