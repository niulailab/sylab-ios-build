#!/bin/bash
cat > /tmp/_se3.py <<'PY'
import json, urllib.request
def run(sid, code):
 payload=json.dumps({"code":code,"language":"python","timeout":60,"session_id":sid}).encode()
 req=urllib.request.Request("http://127.0.0.1:9097/execute",data=payload,headers={"Content-Type":"application/json"})
 d=json.loads(urllib.request.urlopen(req,timeout=90).read().decode())["data"]
 print("== ",sid)
 print("OUT:",d["stdout"][-400:])
 print("ERR:",d["stderr"][-400:])

run("a_min", "print('callable?', callable(globals().get('upload_file')))")
run("a_min2", "import sys; print('pp done'); print(callable(upload_file))")
run("a_cwd", "import os; print('cwd',os.getcwd()); print(callable(upload_file))")
PY
python3 /tmp/_se3.py
echo "[DONE]"
