#!/bin/bash
echo "=== curl public with headers ==="
curl -s -m 20 -i "https://s.symsgf.xyz/project-files/api/files/sbx_stable_1/upload_stable_1.txt" 2>&1 | head -20
echo
echo "=== direct 9093 file ==="
curl -s -m 10 -i "http://127.0.0.1:9093/api/files/sbx_stable_1/upload_stable_1.txt" 2>&1 | head -12
echo
echo "=== screenshot raw (direct browser-service + tool-proxy) ==="
docker exec tool-proxy python3 -c '
import json,urllib.request
for base,path in [("http://browser-service:9096","/browser/screenshot"),("http://localhost:9092","/screenshot")]:
 req=urllib.request.Request(base+path,data=json.dumps({"url":"https://www.baidu.com"}).encode(),headers={"Content-Type":"application/json"})
 try:
  r=json.loads(urllib.request.urlopen(req,timeout=60).read().decode())
  d=r.get("data")
  print(path, "code",r.get("code"),"dtype",type(d).__name__, "b64" , (len(d.get("screenshot_base64","")) if isinstance(d,dict) else str(d)[:80]))
 except Exception as e: print(path,"EXC",repr(e)[:120])
'
echo "[DONE]"
