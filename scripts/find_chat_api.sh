#!/bin/bash
echo "=== grep client endpoints (from tool-proxy? no). check coze-server routes for chat ==="
# The app calls direct.symsgf.xyz:8099. From server host, list nginx proxies
grep -aoE "/v3/chat[a-z/]*|/v1/chat[a-z/]*" /root/coze-studio/docker/*.yml 2>/dev/null | sort -u | head
# Actually query app chat through localhost nginx 8099 if exists
ss -ltn | grep -E ':8099|:80'
echo DONE
