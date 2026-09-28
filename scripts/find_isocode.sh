#!/bin/bash
echo "=== files mentioning isolated code exec / minio hostname ==="
grep -rIl --include='*.py' --include='*.sh' --include='*.go' --include='*.json' \
 -e "code-isolated" -e "execute_code" -e "isolated" /root/coze-studio 2>/dev/null | grep -vE "node_modules|\.git/|browser_service|/server.py$" | head -30
echo "=== grep for the minio wrong hostname usage ==="
grep -rIn --include='*.py' -e "minio:9000" -e "http://minio" -e "MINIO" /root/coze-studio 2>/dev/null | grep -vE "node_modules|\.git/" | head -20
echo "[DONE]"
