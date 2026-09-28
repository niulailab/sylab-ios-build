#!/bin/bash
set -uo pipefail
F=/root/coze-studio/tool-proxy/server.py
TS=$(date +%Y%m%d_%H%M%S)
cp -a "$F" "$F.bak_clean_$TS"

echo "========== STEP1 remove IDENT-DBG =========="
python3 - "$F" <<'PY'
import sys
f=sys.argv[1]
s=open(f,encoding='utf-8').read()

b1=('    sk = _extract_session_key(raw_request)\n'
    '    logging.warning(f"[IDENT-DBG] sk_len={len(sk) if sk else 0} sk_head={(sk or \'\')[:12]}")\n'
    '    if sk:')
a1='    sk = _extract_session_key(raw_request)\n    if sk:'
n1=s.count(b1)
s=s.replace(b1,a1)

b2='''                    row = cur.fetchone()
            finally:
                conn.close()
            logging.warning(f"[IDENT-DBG] match={'YES' if row else 'NO'}")
            if row:
                return str(row["id"]), conv'''
a2='''                    row = cur.fetchone()
            finally:
                conn.close()
            if row:
                return str(row["id"]), conv'''
n2=s.count(b2)
s=s.replace(b2,a2)

print(f"removed dbg blocks: b1={n1} b2={n2}")
left=s.count("IDENT-DBG")
print("remaining IDENT-DBG:",left)
open(f,'w',encoding='utf-8').write(s)
PY
python3 -m py_compile "$F" && echo "compile ok"

echo ""
echo "========== STEP2 containers: browser / minio / file =========="
docker ps -a --format '{{.Names}}\t{{.Status}}\t{{.Ports}}' | grep -iE "browser|minio|file|puppeteer|playwright|screenshot"

echo ""
echo "========== STEP3 host listening ports 9000/3000/etc =========="
ss -ltnp 2>/dev/null | grep -E ":9000|:3000|:8099|:9091" | head

echo ""
echo "========== STEP4 minio-related compose/projects =========="
ls /root/coze-studio/ 2>/dev/null | head -30
echo "[DONE probe]"
