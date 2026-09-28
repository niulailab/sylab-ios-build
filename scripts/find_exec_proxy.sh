#!/bin/bash
echo "=== execute_code / docker run / isolated in tool-proxy server.py ==="
grep -nE "execute_code|code-isolated|docker run|containers/create|def .*code|sandbox|MINIO_HOST|minio:9000" /root/coze-studio/tool-proxy/server.py | head -40
echo "[DONE]"
