#!/bin/bash
cat > /tmp/_probe.py <<'PYEOF'
import json,sys,urllib.request
u=sys.argv[1]; via=sys.argv[2] if len(sys.argv)>2 else "bs"
base="http://localhost:9092" if via=="proxy" else "http://browser-service:9096"
path="/screenshot" if via=="proxy" else "/browser/screenshot"
try:
    req=urllib.request.Request(base+path,
        data=json.dumps({"url":u,"full_page":False}).encode(),
        headers={"Content-Type":"application/json"})
    raw=urllib.request.urlopen(req,timeout=60).read().decode()
    r=json.loads(raw)
    if via=="proxy":
        print("PROXY",u,"code",r.get("code"),"msg",str(r.get("msg"))[:70])
    else:
        d=r.get("data") or {}
        print("BS",u,"b64",len(d.get("screenshot_base64","") or ""),"err",d.get("screenshot_error"),"reach",d.get("reachable"))
except Exception as e:
    print(via,u,"EXC",repr(e)[:160])

PYEOF
echo "=== browser-service direct ==="
for u in https://www.baidu.com https://www.qq.com https://example.com; do
 docker cp /tmp/_probe.py tool-proxy:/tmp/_probe.py
 docker exec tool-proxy python3 -u /tmp/_probe.py "$u" bs
done
echo "=== via tool-proxy /screenshot ==="
for u in https://www.baidu.com https://example.com; do
 docker exec tool-proxy python3 -u /tmp/_probe.py "$u" proxy
done
echo "[DONE]"
