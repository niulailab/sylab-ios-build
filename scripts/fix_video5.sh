#!/bin/bash
echo "=== 1) 查 Coze 框架环境变量里有没有 video/generate 配置 ==="
docker exec coze-server env | grep -iE "video|generate|tool.*url|plugin" | head -20
echo
echo "=== 2) 查 Coze 框架的 .env 或配置文件 ==="
docker exec coze-server bash -c "cat /app/.env 2>/dev/null | grep -iE 'video|generate|tool'" | head
echo
echo "=== 3) 查 tool-proxy 最近 1 小时的视频请求日志 ==="
docker logs tool-proxy --since 1h 2>&1 | grep -iE "POST /video|video.*200|video.*401|video.*500|video.*400" | tail -30
echo
echo "=== 4) 查 Coze 框架日志里 tool call 相关的（看视频工具怎么调的）==="
docker logs coze-server --since 1h 2>&1 | grep -iE "tool.*call|tool.*invoke|tool.*request" | grep -vE "grpc|health" | tail -20
echo
echo "=== 5) 查 Coze 框架二进制里有没有硬编码 video_generate 端点 ==="
docker exec coze-server bash -c "strings /app/opencoze 2>/dev/null | grep -iE 'video.*generate|/video/generate|tool.*proxy' | head -10"
echo "[DONE]"
