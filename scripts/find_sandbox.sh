#!/bin/bash
echo "=== search code-isolated network references in host scripts/conf ==="
grep -rIn --exclude-dir=node_modules --exclude-dir=.git -e "code-isolated" /root 2>/dev/null | grep -vE "\.zip" | head -20
echo "=== search for upload_file tool definition (def upload_file / minio:9000) ==="
grep -rIln --exclude-dir=node_modules --exclude-dir=.git -e "def upload_file" -e "minio:9000" -e "bucket_not_found" /root 2>/dev/null | head -20
echo "=== sandbox/code-run related dirs ==="
ls -dt /root/*code* /root/*sandbox* /root/*runner* 2>/dev/null
echo "[DONE]"
