#!/bin/bash
cat > /tmp/_vin.py <<'PY'
import json, urllib.request
code = r'''
import os, json
# 用注入的工具
with open("_t_up.txt","w") as f: f.write("inject verify content abc123")
r1 = upload_file("_t_up.txt", object_name="inject_test.txt")
print("UPLOAD", json.dumps(r1, ensure_ascii=False)[:220])
r2 = list_files()
print("LIST total", r2.get("total"), "names", [x["name"] for x in r2.get("files", [])][:5])
'''
payload=json.dumps({"code":code,"language":"python","timeout":60,"session_id":"verify_inj_001"}).encode()
req=urllib.request.Request("http://127.0.0.1:9097/execute",data=payload,
    headers={"Content-Type":"application/json"})
r=json.loads(urllib.request.urlopen(req,timeout=90).read().decode())
print("stdout:\n"+r.get("stdout",""))
print("stderr:",r.get("stderr","")[:300])
print("exit",r.get("exit_code"))
PY
python3 /tmp/_vin.py
echo "[DONE]"
