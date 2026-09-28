#!/bin/bash
# ============================================================================
# nginx v140：新增 /schedule/ -> 9092（定时任务管理接口），供 sylab app 访问
# 纯增量；先备份；nginx -t 通过后才 reload；显式透传 Cookie/Host/session
# ============================================================================
set -euo pipefail
F=/etc/nginx/sites-enabled/default
TS=$(date +%Y%m%d_%H%M%S)
BAK="$F.bak_v140ngx_$TS"
cp -a "$F" "$BAK"
echo "[backup] $BAK"

python3 - "$F" <<'PYEOF'
import sys
f = sys.argv[1]
s = open(f, encoding='utf-8').read()

anchor = '''    # Tool-proxy (images, video, etc.)
    location /images/ {
        proxy_pass http://127.0.0.1:9092;
        proxy_connect_timeout 60s;
        proxy_read_timeout 60s;
        proxy_send_timeout 60s;
        add_header Access-Control-Allow-Origin '*' always;
    }
'''

block = anchor + '''
    # Scheduled tasks management (tool-proxy) - app "我的/定时任务"
    location /schedule/ {
        if ($request_method = OPTIONS) {
            add_header Access-Control-Allow-Origin '*' always;
            add_header Access-Control-Allow-Methods 'GET, POST, OPTIONS' always;
            add_header Access-Control-Allow-Headers 'Content-Type, Authorization, X-Session-Key' always;
            return 204;
        }
        proxy_pass http://127.0.0.1:9092;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto https;
        proxy_set_header Cookie $http_cookie;
        proxy_set_header X-Session-Key $cookie_session_key;
        proxy_connect_timeout 30s;
        proxy_read_timeout 120s;
        proxy_send_timeout 30s;
        add_header Access-Control-Allow-Origin '*' always;
    }
'''

n = s.count(anchor)
if n != 1:
    sys.exit(f"[FAIL] anchor count={n}")
s = s.replace(anchor, block)
open(f, 'w', encoding='utf-8').write(s)
print("[ok] /schedule/ block inserted")
PYEOF

echo "=== nginx -t ==="
nginx -t
echo "=== reload ==="
nginx -s reload && echo "[reload] OK"
echo "[DONE]"
