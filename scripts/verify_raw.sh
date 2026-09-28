#!/bin/bash
cat > /tmp/_vraw.py <<'PY'
import json, urllib.request
code = '''
import os, json
open("_t_up.txt","w").write("inject verify abc123")
print("UPLOAD", json.dumps(upload_file("_t_up.txt", "inject_test.txt"), ensure_ascii=False)[:240])
print("LIST", list_files().get("total"))
'''
payload=json.dumps({"code":code,"language":"python","timeout":60,"session_id":"verify_inj_002"}).encode()
req=urllib.request.Request("http://127.0.0.1:9097/execute",data=payload,
    headers={"Content-Type":"application/json"})
raw=urllib.request.urlopen(req,timeout=90).read().decode()
print("RAW:",raw[:1500])
PY
python3 /tmp/_vraw.py
echo "[DONE]"
