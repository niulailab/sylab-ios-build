#!/bin/bash
set -euo pipefail
F=/etc/nginx/sites-enabled/default
TS=$(date +%Y%m%d_%H%M%S)
cp -a "$F" "$F.bak_v141_$TS"
echo "[backup] $F.bak_v141_$TS"

python3 - "$F" <<'PY'
import sys
f=sys.argv[1]
s=open(f,encoding='utf-8').read()
old="        proxy_set_header X-Session-Key $cookie_session_key;"
new="        proxy_set_header X-Session-Key $http_x_session_key;"
n=s.count(old)
if n!=1:
    sys.exit(f"[FAIL] anchor={n}")
s=s.replace(old,new)
open(f,'w',encoding='utf-8').write(s)
print("[ok] header passthrough fixed")
PY

nginx -t
systemctl reload nginx
echo "[reloaded]"

echo ""
echo "=== verify end-to-end via 9091 with owner session key ==="
SK=$(docker exec coze-mysql mysql --default-character-set=utf8mb4 -uroot -pd3G8JG273iE8C4irRWJX opencoze -N -e \
 "SELECT session_key FROM user WHERE id='7666848996043784192';" 2>/dev/null)
echo "session key len=${#SK}"
curl -s -X POST http://127.0.0.1:9091/schedule/list \
 -H 'Content-Type: application/json' \
 -H "x-session-key: $SK" \
 -d '{"scope":"all"}' | base64
echo "[DONE]"
