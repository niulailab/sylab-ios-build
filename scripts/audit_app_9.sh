#!/bin/bash
F=/etc/nginx/sites-enabled/default
echo "=== real default file? ==="
ls -la "$F"
echo "=== listen / server_name ==="
grep -nE "listen|server_name" "$F"
echo ""
echo "=== ALL location blocks + proxy_pass ==="
grep -nE "location |proxy_pass" "$F"
