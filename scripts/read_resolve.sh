#!/bin/bash
F=/root/coze-studio/tool-proxy/server.py
S=$(grep -n "def _resolve_user" "$F" | head -1 | cut -d: -f1)
echo "start=$S"
sed -n "${S},$((S+55))p" "$F" | cat -A | sed -n '1,55p'
