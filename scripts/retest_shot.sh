#!/bin/bash
cat > /tmp/_rt.sh <<'SH'
set -e
echo "=== direct browser-service:9096 ==="
for u in https://www.baidu.com https://www.qq.com https://example.com; do
 R=$(curl -s -m 40 -X POST http://localhost:9096/browser/screenshot -H 'Content-Type: application/json' \
   --data "{\"url\":\"$u\",\"full_page\":false}")
 echo "$u -> $(echo "$R" | python3 -c "import json,sys;r=json.load(sys.stdin);d=r.get('data',{});print('b64len',len(d.get('screenshot_base64','')),'err',d.get('screenshot_error'))" 2>/dev/null || echo "$R" | head -c 200)"
done
SH
docker cp /tmp/_rt.sh tool-proxy:/tmp/_rt.sh 2>/dev/null || true
# run from host via tool-proxy container which has curl and reaches browser-service
docker exec tool-proxy sh -c 'cat > /tmp/_rt.sh' < /tmp/_rt.sh
docker exec tool-proxy sh /tmp/_rt.sh
echo "=== via tool-proxy /screenshot ==="
docker exec tool-proxy sh -c 'curl -s -m 45 -X POST http://localhost:1446/screenshot -H "Content-Type: application/json" --data "{\"url\":\"https://www.baidu.com\"}" -o /tmp/r.json -w "http=%{http_code}\n"; head -c 120 /tmp/r.json; echo'
echo "[DONE]"
