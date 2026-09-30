#!/bin/bash
echo "===== /browser/content 原始返回结构 ====="
curl -s -m 50 -X POST http://localhost:9092/browser/content -H 'Content-Type: application/json' \
 -d '{"url":"https://en.wikipedia.org/wiki/Artificial_intelligence"}' > /tmp/c.json
echo "top-level type:"; python3 -c "
import json;d=json.load(open('/tmp/c.json'))
print('keys=',list(d.keys()),'data type=',type(d.get('data')).__name__)
data=d.get('data')
if isinstance(data,str):
    try:
        ij=json.loads(data);print('inner type=',type(ij).__name__)
        t=ij.get('text','') if isinstance(ij,dict) else ''
        print('textlen=',len(t));print('preview:',t[:150].replace(chr(10),' '))
    except Exception as e: print('not json str:',e, str(data)[:100])
elif isinstance(data,dict):
    t=data.get('text','');print('textlen=',len(t));print('preview:',t[:150].replace(chr(10),' '))
"
echo "[DONE]"
