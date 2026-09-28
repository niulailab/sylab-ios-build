#!/bin/bash
cat > /tmp/_probe.py <<'PYEOF'
import json,sys,urllib.request
u=sys.argv[1]
try:
    req=urllib.request.Request("http://browser-service:9096/browser/screenshot",
        data=json.dumps({"url":u,"full_page":False}).encode(),
        headers={"Content-Type":"application/json"})
    raw=urllib.request.urlopen(req,timeout=50).read().decode()
    r=json.loads(raw); d=r.get("data") or {}
    print("PROBE",u,"b64",len(d.get("screenshot_base64","") or ""),"err",d.get("screenshot_error"),"reach",d.get("reachable"))
except Exception as e:
    print("PROBE",u,"EXC",repr(e)[:160])
PYEOF
echo "### AFTER restart (container was restarted last run)"
for u in https://www.baidu.com https://www.qq.com https://example.com; do
 docker cp /tmp/_probe.py tool-proxy:/tmp/_probe.py
 docker exec tool-proxy python3 -u /tmp/_probe.py "$u"
done
echo "[DONE]"
