#!/bin/bash
echo "===== 旧 tool-proxy 的 compose 标签 ====="
docker inspect tool-proxy --format '{{range $k,$v := .Config.Labels}}{{$k}}={{$v}}{{"\n"}}{{end}}' | grep -i compose
echo ""
echo "===== minio 当前状态/标签/数据 ====="
docker inspect coze-minio --format 'created={{.Created}} status={{.State.Status}}'
docker inspect coze-minio --format '{{index .Config.Labels "com.docker.compose.project"}}'
docker ps --format '{{.Names}}\t{{.Status}}' | grep -E "minio|tool-proxy"
echo "-- minio 数据桶快速确认 --"
docker exec coze-minio ls /data 2>/dev/null | head
echo "[DONE]"
