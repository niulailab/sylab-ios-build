#!/bin/bash

echo "=== Step 1: 找 sylab 后端源码位置 ==="
find /root/coze-studio -name "*.go" -o -name "*.py" | grep -v node_modules | head -20

echo
echo "=== Step 2: 查 tool-proxy server.py 的 video_generate_v2 函数 ==="
grep -n "def video_generate" /root/coze-studio/tool-proxy/server.py | head -10

echo
echo "=== Step 3: 查 sylab 后端处理 tool call 的代码 ==="
# 找后端代码
find /root -maxdepth 3 -name "*.go" | grep -iE "tool|invoke|call" | head -20

echo
echo "=== Step 4: 直接测试 tool-proxy /video/generate（完整请求）==="
RESULT=$(curl -s -X POST http://localhost:5435/video/generate \
  -H "Content-Type: application/json" \
  -H "X-User-Id: app_user" \
  -d '{"action":"quote","duration":5,"prompt":"test"}')
echo "Response: $RESULT"
echo "Response length: $(echo -n "$RESULT" | wc -c)"

echo
echo "=== Step 5: 验证响应是否符合 response schema ==="
echo "Response schema 定义: code(integer), msg(string), data(string)"
echo "实际响应:"
echo "$RESULT" | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    print(f'code type: {type(data.get(\"code\")).__name__}, value: {data.get(\"code\")}')
    print(f'msg type: {type(data.get(\"msg\")).__name__}, value: {data.get(\"msg\")}')
    print(f'data type: {type(data.get(\"data\")).__name__}, value: {str(data.get(\"data\"))[:100]}')
    print('Schema validation: PASS' if all(k in data for k in ['code','msg','data']) else 'Schema validation: FAIL')
except Exception as e:
    print(f'JSON parse error: {e}')
"

echo
echo "=== Step 6: 查 sylab 后端 tool call 日志（找 video_generate 相关）==="
docker logs coze-server --since 1h 2>&1 | grep -E "video_generate|video/status" | grep -vE "save_memory|grpc|health|Method=" | tail -20

echo "[DONE]"
