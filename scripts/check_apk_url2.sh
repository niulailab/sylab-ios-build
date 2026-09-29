#!/bin/bash
echo "=== 跟随重定向 ==="
curl -sIL "http://127.0.0.1/apks/apk_build_test_20260929.apk" 2>&1 | grep -iE "HTTP/|location:|content-length|content-type" | head -12
echo
echo "=== sylab server_name ==="
grep -nE "server_name" /etc/nginx/sites-available/sylab 2>/dev/null | head -3
echo "[DONE]"
