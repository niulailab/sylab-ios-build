#!/bin/bash
echo "=== 1) 完整裸调 callback（看响应体+头）==="
curl -s -i -X POST "http://coze-server:8888/api/v1/video/callback" \
  -H "Content-Type: application/json" -d '{"task_id":"x","status":"completed"}' 2>&1 | head -25
echo
echo "=== 2) 二进制里 video/callback 及附近鉴权字符串 ==="
docker exec coze-server bash -c "strings /app/opencoze 2>/dev/null | grep -iE 'video/callback' | head"
echo
echo "=== 3) callback 可能期望的 header 名 / secret 名 ==="
docker exec coze-server bash -c "strings /app/opencoze 2>/dev/null | grep -iE 'X-(Callback|Internal|Video|Task)|callback.*(secret|token|key)|VIDEO_CALLBACK' | sort -u | head -25"
echo
echo "=== 4) coze-server .env 里跟 internal/callback/video 相关的配置 ==="
docker exec coze-server bash -c "grep -iE 'internal|callback|video|secret|token|key' /app/.env 2>/dev/null | sed 's/=.*/=<hidden>/'" | head -30
echo "[DONE]"
