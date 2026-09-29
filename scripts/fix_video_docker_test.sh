#!/bin/bash

echo "=== Step 1: 查 tool-proxy 容器端口映射 ==="
docker port tool-proxy

echo
echo "=== Step 2: 用 docker exec 在 tool-proxy 容器内测试 /video/generate ==="
echo "--- Test quote ---"
docker exec tool-proxy python3 -c "
import urllib.request, json
req = urllib.request.Request(
    'http://localhost:5435/video/generate',
    data=json.dumps({'action':'quote','duration':5,'prompt':'test cat'}).encode(),
    headers={'Content-Type':'application/json'}
)
try:
    resp = urllib.request.urlopen(req, timeout=30)
    body = resp.read().decode()
    print(f'Status: {resp.status}')
    print(f'Body: {body[:500]}')
except Exception as e:
    print(f'Error: {e}')
"

echo
echo "--- Test generate (with user_id header) ---"
docker exec tool-proxy python3 -c "
import urllib.request, json
req = urllib.request.Request(
    'http://localhost:5435/video/generate',
    data=json.dumps({'action':'generate','duration':5,'prompt':'test cat'}).encode(),
    headers={'Content-Type':'application/json','X-User-Id':'app_user'}
)
try:
    resp = urllib.request.urlopen(req, timeout=30)
    body = resp.read().decode()
    print(f'Status: {resp.status}')
    print(f'Body: {body[:500]}')
except Exception as e:
    print(f'Error: {e}')
"

echo
echo "=== Step 3: 查 sylab 后端后端调用 tool-proxy 的日志（找 video_generate 的请求和响应）==="
docker logs coze-server --since 1h 2>&1 | grep -E "POST.*video/generate|video_generate" | grep -vE "save_memory|grpc|health|Method=|resp:" | tail -20

echo
echo "=== Step 4: 查 sylab 后端对 video_generate 的响应解析（找 OnEnd 日志）==="
docker logs coze-server --since 1h 2>&1 | grep -B2 -A5 "video_generate\|video_generate_v2" | grep -vE "save_memory|grpc|health|Method=|resp:" | tail -40

echo "[DONE]"
