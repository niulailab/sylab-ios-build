#!/bin/bash
F=/root/coze-studio/tool-proxy/server.py
echo "=== screenshot / browser refs ==="
grep -nE "screenshot|9096|BROWSER|browser-service|screenshot_base64" "$F" | head -30
echo ""
echo "=== upload / minio refs ==="
grep -nE "upload_file|minio|9000|MINIO|bucket|object_name|put_object" "$F" | head -40
