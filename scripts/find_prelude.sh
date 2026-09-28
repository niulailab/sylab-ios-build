#!/bin/bash
echo "=== upload_file / list_files / def prelude / python injection ==="
grep -nE "upload_file|list_files|write_file|PYTHON_PRELUDE|prelude|def upload|requests.put|boto3|import boto|minio" /root/code_exec_server.js | head -40
echo "[DONE]"
