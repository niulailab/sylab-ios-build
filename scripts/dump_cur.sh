#!/bin/bash
grep -n 'else:' /root/coze-studio/tool-proxy/server.py | grep -A1 -B1 -E '2[0-9]{3}' | tail -20
echo "=== context around exhausted logic ==="
sed -n '2240,2290p' /root/coze-studio/tool-proxy/server.py
echo DONE
