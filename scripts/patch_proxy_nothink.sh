#!/bin/bash
F=/root/coze-studio/tool-proxy/server.py
cp "$F" "$F.bak_nothink_$(date +%s)"
python3 - "$F" <<'PY'
import sys,re
f=sys.argv[1]
s=open(f).read()
old='                payload["reasoning_effort"] = "low"'
new='''                payload["reasoning_effort"] = "none"
                # force zero reasoning: long CoT is what triggers false "jailbreak" refusals
                payload["thinking"] = {"type": "disabled"}
                payload["enable_thinking"] = False
                payload["extra_body"] = {"thinking": {"type": "disabled"}}'''
assert old in s, "inject line not found"
s=s.replace(old,new,1)
open(f,'w').write(s)
print("patched")
PY
grep -n 'reasoning_effort\|enable_thinking\|"thinking"' "$F" | head
echo "=== restart tool-proxy ==="
TP=$(docker ps --format '{{.Names}}'|grep -i tool-proxy|head -1)
docker restart "$TP" >/dev/null && echo restarted
sleep 6
docker exec "$TP" sh -lc "python3 -c 'import ast;ast.parse(open(\"/app/server.py\").read());print(\"syntax ok\")'"
echo DONE
