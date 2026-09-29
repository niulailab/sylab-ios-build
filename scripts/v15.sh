#!/bin/bash
echo "===== tool-proxy openapi 里 browser/content/screenshot 相关路由 ====="
curl -s -m 20 http://localhost:9092/openapi.json | python3 -c "
import json,sys
d=json.load(sys.stdin)
for p in sorted(d.get('paths',{})):
    if 'browser' in p or 'content' in p or 'screenshot' in p or 'crawl' in p or 'fetch' in p:
        print(p, list(d['paths'][p].keys()))
"
echo ""
echo "===== server.py 里 browser content 转发定义 ====="
grep -n "browser/content\|/content\|browser-service:9096\|def.*content\|@app.post" /root/coze-studio/tool-proxy/server.py | grep -i "content\|browser" | head -20
echo "[DONE]"
