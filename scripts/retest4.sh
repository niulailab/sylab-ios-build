#!/bin/bash
cat > /tmp/_r4.py <<'PY'
import json, urllib.request
def hit(base,path,u):
    try:
        req=urllib.request.Request(base+path,
            data=json.dumps({"url":u,"full_page":False}).encode(),
            headers={"Content-Type":"application/json"})
        raw=urllib.request.urlopen(req,timeout=50).read().decode()
        try:
            r=json.loads(raw)
            if path.endswith("/screenshot") and "browser" not in base:
                d=r.get("data")
                print(path,u,"code",r.get("code"),"msg",str(r.get("msg"))[:80])
            else:
                d=r.get("data") or {}
                print(path,u,"b64",len(d.get("screenshot_base64","") or ""),"err",d.get("screenshot_error"),"reach",d.get("reachable"))
        except Exception:
            print(path,u,"RAW",raw[:200])
    except urllib.error.HTTPError as e:
        print(path,u,"HTTP",e.code,e.read().decode()[:160])
    except Exception as e:
        print(path,u,"EXC",repr(e)[:150])
for u in ["https://www.baidu.com","https://example.com"]:
    hit("http://browser-service:9096","/browser/screenshot",u)
for u in ["https://www.baidu.com","https://example.com"]:
    hit("http://localhost:9092","/screenshot",u)
PY
docker cp /tmp/_r4.py tool-proxy:/tmp/_r4.py
docker exec tool-proxy python3 -u /tmp/_r4.py 2>&1
echo "[DONE]"
