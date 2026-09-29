#!/bin/bash

echo "=== Step 1: 测试 tool-proxy /video/generate（直接请求，模拟 AI 调用）==="
echo "--- Test quote ---"
RESULT=$(curl -s -w "\nHTTP_CODE:%{http_code}" -X POST http://localhost:5435/video/generate \
  -H "Content-Type: application/json" \
  -d '{"action":"quote","duration":5,"prompt":"test cat"}')
echo "$RESULT"

echo
echo "--- Test generate (with user_id) ---"
RESULT2=$(curl -s -w "\nHTTP_CODE:%{http_code}" -X POST http://localhost:5435/video/generate \
  -H "Content-Type: application/json" \
  -H "X-User-Id: app_user" \
  -d '{"action":"generate","duration":5,"prompt":"test cat"}')
echo "$RESULT2"

echo
echo "=== Step 2: 查 tool-proxy 最近请求日志（看 AI 调用时的认证信息）==="
docker logs tool-proxy --since 10m 2>&1 | grep -E "INFO|DEBUG|ERROR" | tail -50

echo
echo "=== Step 3: 查 tool-proxy 的认证配置（看怎么验证请求来源）==="
docker exec tool-proxy grep -r "auth\|token\|api_key\|session" /app/server.py 2>/dev/null | head -20

echo
echo "=== Step 4: 查 Coze framework 最近工具调用（找 video_generate 相关）==="
docker logs coze-server --since 30m 2>&1 | grep -E "video_generate|video/status|call_" | grep -vE "save_memory|grpc|health|Method=" | tail -30

echo
echo "=== Step 5: 查 Coze framework 的工具执行日志（找最近一次 tool call 的完整流程）==="
docker logs coze-server --since 10m 2>&1 | grep -E "OnStart|OnFinish|tool_calls" | tail -30

echo "[DONE]"
