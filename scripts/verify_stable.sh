#!/bin/bash
cat > /tmp/_vs.py <<'PY'
import json, urllib.request
def run(n):
 code='''
open("_f%d.txt","w").write("stable content %d")
u=upload_file("_f%d.txt", object_name="stable_%d.txt")
print("UP", u.get("code"), u.get("url"))
l=list_files(); print("TOTAL", l.get("total"))
nm=[f["name"] for f in l["files"] if "stable_%d" in f["name"]][0]
d=download_file(nm, save_path="_d%d.txt"); print("DL", d.get("code"), open("_d%d.txt").read())
''' % (n,n,n,n,n,n,n)
 payload=json.dumps({"code":code,"language":"python","timeout":60,"session_id":"stable_%d"%n}).encode()
 req=urllib.request.Request("http://127.0.0.1:9097/execute",data=payload,headers={"Content-Type":"application/json"})
 d=json.loads(urllib.request.urlopen(req,timeout=90).read().decode())["data"]
 print("== run",n,"exit",d["exit_code"])
 print(d["stdout"].strip())
 if d["stderr"].strip(): print("ERR",d["stderr"][:200])
for n in range(1,4): run(n)
PY
python3 /tmp/_vs.py
echo "[DONE]"
