#!/bin/bash
echo "=== full response (baidu) ==="
curl -s -m 45 -X POST http://127.0.0.1:9096/browser/screenshot \
 -H 'Content-Type: application/json' \
 -d '{"url":"https://www.baidu.com","full_page":false}'
echo ""
echo ""
echo "=== try a couple more URLs ==="
for u in "https://example.com" "https://www.qq.com"; do
 echo "--- $u ---"
 curl -s -m 45 -X POST http://127.0.0.1:9096/browser/screenshot \
  -H 'Content-Type: application/json' \
  -d "{\"url\":\"$u\",\"full_page\":false}" | python3 -c "
import json,sys
d=json.load(sys.stdin)
data=d.get('data',{})
print('reachable=',data.get('reachable'),'b64len=',len(data.get('screenshot_base64','')),'err=',data.get('screenshot_error','')[:200])"
done
