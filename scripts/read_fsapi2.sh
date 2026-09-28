#!/bin/bash
echo "=== GET /api/files 118-224 ==="
sed -n '118,224p' /root/sylab-app/file_service.py
echo "=== POST upload 252-310 ==="
sed -n '252,310p' /root/sylab-app/file_service.py
echo "[DONE]"
