#!/bin/bash
echo "=== 1) coze-server /app 结构 ==="
docker exec coze-server bash -c "ls -la /app 2>/dev/null" | head
echo
echo "=== 2) grep callback 路由（含 jar 内字符串）==="
docker exec coze-server bash -c "grep -rln 'video/callback' /app 2>/dev/null | head"
docker exec coze-server bash -c "find /app -maxdepth 3 -name '*.jar' 2>/dev/null | head"
echo
echo "=== 3) 直接裸调 callback 复现 401，看响应头有没有鉴权提示 ==="
curl -s -i -X POST "http://coze-server:8888/api/v1/video/callback" \
  -H "Content-Type: application/json" -d '{}' 2>&1 | head -20
echo
echo "=== 4) 试探该服务其他内部端点的鉴权方式（找 internal header 规律）==="
# tool-proxy 里历史上有没有成功调过 coze-server 内部接口、带什么头
grep -nE "coze-server:8888|X-Internal|X-Api|internal.*key|8888.*header|video/callback" /root/coze-studio/tool-proxy/server.py | head
echo "[DONE]"
