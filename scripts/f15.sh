#!/bin/bash
probe(){
 curl -s -m 55 -X POST http://localhost:9092/browser/content -H 'Content-Type: application/json' \
  -d "{\"url\":\"$1\"}" > /tmp/p.json
 python3 -c "
import json;d=json.load(open('/tmp/p.json'));data=d.get('data')
try: ij=json.loads(data) if isinstance(data,str) else data
except: ij={}
t=ij.get('text','') if isinstance(ij,dict) else ''
print('$2: len=',len(t))
print('  head:',repr(t[:90]))
print('  tail:',repr(t[-60:]))
"
}
probe "https://en.wikipedia.org/wiki/Artificial_intelligence" "wiki-AI"
probe "https://www.baidu.com/s?wd=artificial+intelligence" "baidu"
probe "https://example.com" "example"
echo ""
echo "===== browser-service content 实现是否截断 ====="
docker exec browser-service sh -c 'ls /app; grep -rn "text\[:\|max\|slice\|2000\|5000" /app/*.py 2>/dev/null | grep -iE "text|len|limit" | head'
echo "[DONE]"
