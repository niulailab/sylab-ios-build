#!/bin/bash
echo "=== public url download via s.symsgf.xyz ==="
curl -s -m 20 "https://s.symsgf.xyz/project-files/api/files/sbx_stable_1/upload_stable_1.txt"; echo
echo "=== screenshot still works (baidu via tool-proxy) ==="
docker exec tool-proxy python3 -c '
import json,urllib.request
req=urllib.request.Request("http://localhost:9092/screenshot",data=json.dumps({"url":"https://www.baidu.com"}).encode(),headers={"Content-Type":"application/json"})
r=json.loads(urllib.request.urlopen(req,timeout=60).read().decode())
print("screenshot code",r.get("code"),"has b64", bool((r.get("data") or {}).get("screenshot_base64")))
'
echo "=== services health ==="
ss -ltn 2>/dev/null | grep -qE ":9097" && echo "sandbox 9097 UP"
ss -ltn 2>/dev/null | grep -qE ":9093" && echo "filesvc 9093 UP"
docker ps --format '{{.Names}} {{.Status}}' | grep -E "browser-service|coze-minio|tool-proxy|coze-server"
echo "[DONE]"
