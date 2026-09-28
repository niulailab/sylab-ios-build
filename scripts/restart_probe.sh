#!/bin/bash
OUT=/tmp/bs_out.txt
: > $OUT
probe(){
docker exec tool-proxy python3 -u - "$1" >>$OUT 2>&1 <<'PY'
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
PY
}
echo "### BEFORE restart" >>$OUT
probe https://www.baidu.com
echo "### restarting browser-service" >>$OUT
docker restart browser-service >>$OUT 2>&1
sleep 18
echo "### AFTER restart" >>$OUT
probe https://www.baidu.com
probe https://www.qq.com
probe https://example.com
cat $OUT
echo "[DONE]"
