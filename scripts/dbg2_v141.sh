#!/bin/bash
set -euo pipefail
F=/root/coze-studio/tool-proxy/server.py
TS=$(date +%Y%m%d_%H%M%S)
cp -a "$F" "$F.bak_dbg2_$TS"

python3 - "$F" <<'PY'
import sys
f=sys.argv[1]
s=open(f,encoding='utf-8').read()

a1='    sk = _extract_session_key(raw_request)\n    if sk:'
b1=('    sk = _extract_session_key(raw_request)\n'
    '    logging.warning(f"[IDENT-DBG] sk_len={len(sk) if sk else 0} sk_head={(sk or \'\')[:12]}")\n'
    '    if sk:')
assert s.count(a1)==1, ("a1",s.count(a1))
s=s.replace(a1,b1)

a2='''                    row = cur.fetchone()
            finally:
                conn.close()
            if row:
                return str(row["id"]), conv'''
b2='''                    row = cur.fetchone()
            finally:
                conn.close()
            logging.warning(f"[IDENT-DBG] match={'YES' if row else 'NO'}")
            if row:
                return str(row["id"]), conv'''
assert s.count(a2)==1, ("a2",s.count(a2))
s=s.replace(a2,b2)

open(f,'w',encoding='utf-8').write(s)
print("injected")
PY
python3 -m py_compile "$F" && echo "compile ok"
docker restart tool-proxy
sleep 6
echo "[DONE]"
