#!/bin/bash
echo "lines: $(wc -l < /root/code_exec_server.js)"
echo "=== minio/upload/s3/bucket refs ==="
grep -nE "minio|upload|s3|bucket|9000|MINIO|def upload|prelude|inject" /root/code_exec_server.js | head -50
echo "[DONE]"
