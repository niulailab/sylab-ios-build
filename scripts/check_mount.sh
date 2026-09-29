#!/bin/bash
echo "=== docker inspect tool-proxy mounts ==="
docker inspect tool-proxy --format '{{json .Mounts}}' | python3 -m json.tool 2>/dev/null | head -40
echo
echo "=== container server.py mtime/inode ==="
docker exec tool-proxy ls -li /app/server.py
echo
echo "=== host server.py mtime/inode ==="
ls -li /root/coze-studio/tool-proxy/server.py
echo
echo "=== compare md5 ==="
docker exec tool-proxy md5sum /app/server.py
md5sum /root/coze-studio/tool-proxy/server.py
echo "[DONE]"
