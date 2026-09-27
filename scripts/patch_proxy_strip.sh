#!/bin/bash
F=/root/coze-studio/tool-proxy/server.py
TS=$(date +%Y%m%d_%H%M%S)
cp "$F" "/root/backups/server.py.bak_strip_$TS" 2>/dev/null || cp "$F" "/tmp/server.py.bak_strip_$TS"
python3 - "$F" <<'PY'
import sys,re
f=sys.argv[1]
s=open(f).read()
old='''                payload["reasoning_effort"] = "low"
                body = json.dumps(payload, ensure_ascii=False).encode("utf-8")'''
new='''                # 强制最低思考档，并清除任何会导致"关闭思考"的字段
                payload["reasoning_effort"] = "low"
                for _k in ("thinking","thinking_type","enable_thinking","thinking_budget"):
                    if _k in payload:
                        payload.pop(_k, None)
                try:
                    print("[zhipu-strip] incoming keys=", list(payload.keys()), flush=True)
                except Exception:
                    pass
                body = json.dumps(payload, ensure_ascii=False).encode("utf-8")'''
if old not in s:
    print("ANCHOR NOT FOUND"); sys.exit(1)
s=s.replace(old,new,1)
open(f,'w').write(s)
print("patched")
PY
python3 -m py_compile "$F" && echo "syntax OK"
docker restart tool-proxy >/dev/null && echo "proxy restarted"
sleep 6
echo DONE
