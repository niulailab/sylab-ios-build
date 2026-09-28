#!/bin/bash
cat > /tmp/_se2.py <<'PY'
import json, urllib.request
code = '''
import json
open("_final.txt","w").write("final inject verify xyz789")
u = upload_file("_final.txt", object_name="final_test.txt")
print("UPLOAD code", u.get("code"), "url", u.get("url"))
l = list_files()
print("LIST total", l.get("total"))
d = download_file([f["name"] for f in l["files"] if "final" in f["name"]][0], save_path="_dl.txt")
print("DOWNLOAD", d.get("code"), open("_dl.txt").read())
'''
payload=json.dumps({"code":code,"language":"python","timeout":60,"session_id":"verify_final_2"}).encode()
req=urllib.request.Request("http://127.0.0.1:9097/execute",data=payload,
    headers={"Content-Type":"application/json"})
r=json.loads(urllib.request.urlopen(req,timeout=90).read().decode())["data"]
print("STDOUT:",r["stdout"])
print("STDERR:",r["stderr"])
PY
python3 /tmp/_se2.py
echo "[DONE]"
