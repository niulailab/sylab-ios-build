#!/bin/bash
echo "=== imports head (1-40) ==="
sed -n '1,40p' /root/coze-studio/tool-proxy/server.py
echo ""
echo "=== get_db_connection definition ==="
grep -n "def get_db_connection" /root/coze-studio/tool-proxy/server.py
sed -n "$(grep -n 'def get_db_connection' /root/coze-studio/tool-proxy/server.py | head -1 | cut -d: -f1),+25p" /root/coze-studio/tool-proxy/server.py
echo ""
echo "=== helper time funcs present ==="
grep -nE "^def _now|^def _td|^def _dt|def _parse_once_run|def _calc_next|def _calc_first_run|def _freq_text" /root/coze-studio/tool-proxy/server.py
