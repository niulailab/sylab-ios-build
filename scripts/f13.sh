#!/bin/bash
echo "===== 1) 新路由 ====="
curl -s -m 15 http://localhost:9092/openapi.json | python3 -c "
import json,sys;d=json.load(sys.stdin)
for p in ['/browser/content','/screenshot','/v1/web-search']:print(p,'YES' if p in d['paths'] else 'NO')
print('total=',len(d['paths']))
"
echo ""
echo "===== 2) content 抓取(主流站 wikipedia) ====="
curl -s -m 50 -X POST http://localhost:9092/browser/content -H 'Content-Type: application/json' \
 -d '{"url":"https://en.wikipedia.org/wiki/Artificial_intelligence"}' | python3 -c "
import json,sys;d=json.load(sys.stdin);t=(d.get('data') or {}).get('text','')
print('code=',d.get('code'),'textlen=',len(t));print('preview:',t[:120].replace(chr(10),' '))
"
echo ""
echo "===== 3) 博查主通道 ====="
curl -s -m 35 -X POST http://localhost:9092/v1/web-search -H 'Content-Type: application/json' \
 -d '{"query":"OpenAI 最新发布","count":3}' > /tmp/bocha_test.json
python3 -c "
import json;d=json.load(open('/tmp/bocha_test.json'))
if isinstance(d.get('data'),dict):
  dd=d['data'];print('source=',dd.get('source'),'total=',dd.get('total'),'bocha_error=',dd.get('bocha_error'))
  for r in (dd.get('results') or [])[:3]:print(' -',r.get('title','')[:45])
else: print('RAW:',str(d)[:300])
"
echo "[DONE]"
