#!/bin/bash
echo "=== FILE_SERVICE / constants def ==="
grep -nE "FILE_SERVICE|const .*=.*process.env|MINIO|DOWNLOAD|BASE_URL|http://" /root/code_exec_server.js | head -30
echo "=== context 1300-1420 (upload tool) ==="
sed -n '1300,1420p' /root/code_exec_server.js
echo "[DONE]"
