#!/bin/bash
cat > /tmp/_r3.py <<'PY'
import json, urllib.request
def hit(base,path,u):
    try:
        req=urllib.request.Request(base+path,
            data=json.dumps({"url":u,"full_page":False}).encode(),
            headers={"Content-Type":"application/json"})
        r=json.load(urllib.request.urlopen(req,timeout=50))
        d=r.get("data",{})
        print(path,u,"b64len",len(d.get("screenshot_base64","") or ""),"err",d.get("screenshot_error"),"reach",d.get("reachable"))
    except Exception as e:
        print(path,u,"EXC",repr(e)[:150])
for u in ["https://www.baidu.com","https://www.qq.com","https://example.com"]:
    hit("http://browser-service:9096","/browser/screenshot",u)
print("--- via tool-proxy ---")
for u in ["https://www.baidu.com","https://example.com"]:
    hit("http://localhost:9092","/screenshot",u)
PY
docker cp /tmp/_r3.py tool-proxy:/tmp/_r3.py
docker exec tool-proxy python3 -u /tmp/_r3.py 2>&1
echo "[DONE]"
