#!/bin/bash
echo "=== _watch_final / _sweep / STATUS_URL region ==="
grep -n "_watch_final\|_sweep_once_orphans\|STATUS_URL\|result_status" /root/coze-studio/tool-proxy/server.py
echo ""
echo "=== show sweep + watch SQL block ==="
START=$(grep -n "STATUS_URL =" /root/coze-studio/tool-proxy/server.py | head -1 | cut -d: -f1)
sed -n "${START},$((START+120))p" /root/coze-studio/tool-proxy/server.py
