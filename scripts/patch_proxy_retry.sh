#!/bin/bash
F=/root/coze-studio/tool-proxy/server.py
python3 - "$F" <<'PY'
import sys
f=sys.argv[1];s=open(f).read()
old='''                payload["reasoning_effort"] = "none"
                # force zero reasoning: long CoT is what triggers false "jailbreak" refusals
                payload["thinking"] = {"type": "disabled"}
                payload["enable_thinking"] = False
                payload["extra_body"] = {"thinking": {"type": "disabled"}}'''
new='''                payload["reasoning_effort"] = "low"'''
assert old in s
s=s.replace(old,new,1)
open(f,'w').write(s)
print("reverted to low")
PY
grep -n 'reasoning_effort' "$F" | head
echo DONE
