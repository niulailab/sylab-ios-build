#!/bin/bash
echo "=== 1) 查 Coze 框架日志里 video_generate 相关 ==="
docker logs coze-server --since 24h 2>&1 | grep -iE "video|tool.*call|tool.*invoke" | grep -vE "grpc|health" | tail -40
echo
echo "=== 2) 查 tool-proxy 日志里来自 coze-server 的 video 请求 ==="
docker logs tool-proxy --since 24h 2>&1 | grep -iE "POST /video|video.*200|video.*401|video.*500" | tail -20
echo
echo "=== 3) 查环境变量/配置文件里有没有 video_generate 的端点配置 ==="
docker exec coze-server bash -c "grep -iE 'video|generate' /app/.env 2>/dev/null" | head
echo
echo "=== 4) 查 Coze 框架代码里有没有硬编码 video_generate ==="
docker exec coze-server bash -c "strings /app/opencoze | grep -i 'video_generate\|/video/generate' | head -10"
echo
echo "=== 5) 查 Coze 插件表（plugin_version）里有没有视频插件 ==="
docker exec coze-mysql mysql -uroot -pd3G8JG273iE8C4irRWJX opencoze -N -e "
SELECT id, plugin_id, version, status FROM plugin_version WHERE plugin_id IN (
  SELECT id FROM plugin WHERE name LIKE '%video%' OR name LIKE '%视频%' OR name LIKE '%H3%'
) ORDER BY id DESC LIMIT 20;" 2>/dev/null
echo "[DONE]"
