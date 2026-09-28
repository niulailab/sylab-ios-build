#!/bin/bash
echo "=== tool-proxy port ==="
docker port tool-proxy 2>/dev/null
docker exec tool-proxy sh -c 'netstat -ltnp 2>/dev/null | grep -E "1446|909" || ss -ltn 2>/dev/null | head' 2>/dev/null
echo "=== python hit browser-service via host mapped port ==="
python3 - <<'PY'
import json, urllib.request
# browser-service published?
for base in ["http://127.0.0.1:9096"]:
    for u in ["https://www.baidu.com","https://www.qq.com","https://example.com"]:
        try:
            req=urllib.request.Request(base+"/browser/screenshot",
                data=json.dumps({"url":u,"full_page":False}).encode(),
                headers={"Content-Type":"application/json"})
            r=json.load(urllib.request.urlopen(req,timeout=45))
            d=r.get("data",{})
            print(base,u,"b64len",len(d.get("screenshot_base64","")),"err",d.get("screenshot_error"))
        except Exception as e:
            print(base,u,"EXC",repr(e)[:150])
PY
echo "[DONE]"
