#!/bin/bash
cd /root/coze-studio/docker || exit 1
echo "===== 重建 tool-proxy ====="
docker compose up -d --force-recreate tool-proxy 2>&1 | tail -8
sleep 12
echo ""
echo "===== 容器状态/创建时间 ====="
docker inspect tool-proxy --format 'created={{.Created}} image={{.Config.Image}} status={{.State.Status}}'
docker exec tool-proxy printenv | grep -i bocha | sed -E 's/(sk-.{6}).*/\1****/'
echo ""
echo "===== 1) 新路由存在性 ====="
curl -s -m 15 http://localhost:9092/openapi.json | python3 -c "
import json,sys
d=json.load(sys.stdin)
for p in ['/browser/content','/screenshot','/v1/web-search']:
    print(p, 'YES' if p in d['paths'] else 'NO')
print('total paths=',len(d['paths']))
"
echo ""
echo "===== 2) content 转发实测(example.com) ====="
curl -s -m 45 -X POST http://localhost:9092/browser/content -H 'Content-Type: application/json' \
 -d '{"url":"https://example.com"}' | python3 -c "import json,sys;d=json.load(sys.stdin);print('code=',d.get('code'),'textlen=',len((d.get('data') or {}).get('text','')))"
echo ""
echo "===== 3) 博查主通道实测 ====="
curl -s -m 35 -X POST http://localhost:9092/v1/web-search -H 'Content-Type: application/json' \
 -d '{"query":"OpenAI 最新模型","count":3}' | python3 -c "
import json,sys
d=json.load(sys.stdin).get('data',{})
print('source=',d.get('source'),'total=',d.get('total'),'bocha_error=',d.get('bocha_error'))
for r in (d.get('results') or [])[:3]: print(' -',r.get('title','')[:40],'|',r.get('url','')[:50])
"
echo "[DONE]"
