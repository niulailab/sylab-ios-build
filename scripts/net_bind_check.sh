#!/bin/bash
echo "=== 9092 bind address ==="
ss -ltnp | grep ':9092'
echo ""
echo "=== 9088 / 9091 binds ==="
ss -ltnp | grep -E ':9088|:9091'
echo ""
echo "=== how tool-proxy started (host/port) ==="
ps aux | grep -E "tool.proxy|9092" | grep -v grep | head
grep -nE "uvicorn|0.0.0.0|host=" /root/coze-studio/tool-proxy/*.sh /root/coze-studio/tool-proxy/Dockerfile 2>/dev/null | head
docker ps --format '{{.Names}} {{.Ports}}' | grep -iE "tool|proxy"
