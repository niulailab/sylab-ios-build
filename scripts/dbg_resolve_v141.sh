#!/bin/bash
set -euo pipefail
F=/root/coze-studio/tool-proxy/server.py
TS=$(date +%Y%m%d_%H%M%S)
cp -a "$F" "$F.bak_dbg_$TS"

python3 - "$F" <<'PY'
import sys
f=sys.argv[1]
s=open(f,encoding='utf-8').read()

# locate _resolve_user and inject debug logs around session lookup
anchor='''    sk = _extract_session_key(raw_request)
    if sk:
        try:
            conn = get_db_connection()
            try:
                with conn.cursor() as cur:
                    cur.execute(
                        "SELECT id FROM user WHERE session_key=%s AND deleted_at IS NULL LIMIT 1",
                        (sk,))
                    row = cur.fetchone()
            finally:
                conn.close()
            if row:
                return str(row["id"]), conv
        except Exception:
            pass'''
n=s.count(anchor)
if n!=1:
    sys.exit(f"[FAIL] resolve anchor={n}")

replacement='''    sk = _extract_session_key(raw_request)
    if sk:
        try:
            conn = get_db_connection()
            try:
                with conn.cursor() as cur:
                    cur.execute(
                        "SELECT id FROM user WHERE session_key=%s AND deleted_at IS NULL LIMIT 1",
                        (sk,))
                    row = cur.fetchone()
            finally:
                conn.close()
            logging.warning(f"[IDENT-DBG] sk_present len={len(sk)} head={sk[:10]} match={'YES' if row else 'NO'}")
            if row:
                return str(row["id"]), conv
        except Exception as _e:
            logging.warning(f"[IDENT-DBG] lookup error {_e}")
    else:
        logging.warning("[IDENT-DBG] no session key extracted")'''
s=s.replace(anchor,replacement)
open(f,'w',encoding='utf-8').write(s)
print("[ok] debug injected")
PY

python3 -m py_compile "$F" && echo "compile ok"
docker restart tool-proxy
sleep 5
curl -s -o /dev/null http://127.0.0.1:9092/health 2>/dev/null || true
echo "[DONE - now ask user to pull refresh]"
