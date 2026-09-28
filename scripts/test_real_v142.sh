#!/bin/bash
set -uo pipefail
echo "=== A) browser-service direct /browser/screenshot ==="
curl -s -m 45 -X POST http://127.0.0.1:9096/browser/screenshot \
 -H 'Content-Type: application/json' \
 -d '{"url":"https://www.baidu.com","full_page":false}' \
 -o /tmp/shot_resp.json -w "http=%{http_code} size=%{size_download}\n"
echo "--- response keys / base64 length ---"
python3 - <<'PY'
import json
try:
    d=json.load(open('/tmp/shot_resp.json'))
    print("top keys:",list(d.keys()))
    inner=d.get('data')
    if isinstance(inner,dict):
        b=inner.get('screenshot_base64','')
        print("screenshot_base64 len:",len(b))
    else:
        print("data type:",type(inner), str(d)[:300])
except Exception as e:
    print("parse fail:",e)
    print(open('/tmp/shot_resp.json').read()[:300])
PY

echo ""
echo "=== B) tool-proxy /screenshot (full chain) ==="
curl -s -m 50 -X POST http://127.0.0.1:9092/screenshot \
 -H 'Content-Type: application/json' \
 -d '{"url":"https://www.baidu.com"}' \
 -o /tmp/shot2.json -w "http=%{http_code} size=%{size_download}\n"
head -c 350 /tmp/shot2.json; echo ""

echo ""
echo "=== C) upload via /minio-files (PUT) ==="
echo "hello probe $(date)" > /tmp/probe.txt
curl -s -m 20 -X PUT http://127.0.0.1:9092/minio-files/opencoze/probe_v142.txt \
 --data-binary @/tmp/probe.txt -w "\nhttp=%{http_code}\n"
echo ""
echo "=== D) read it back ==="
curl -s -m 15 http://127.0.0.1:9092/minio-files/opencoze/probe_v142.txt -w "\nhttp=%{http_code}\n"
echo "[DONE]"
