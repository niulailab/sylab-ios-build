#!/bin/bash
KEY="sk-bb71bcccb3854dab839ed20c2439d7709c3a75dff8080712"
IMG="https://upload.wikimedia.org/wikipedia/commons/thumb/4/47/PNG_transparency_demonstration_1.png/320px-PNG_transparency_demonstration_1.png"
for M in glm-5.2 hy3 deepseek-v4-pro glm-5.3; do
echo "===== $M vision ====="
curl -s -m 60 "https://laneai.dev/v1/chat/completions" -H "Authorization: Bearer $KEY" -H "Content-Type: application/json" --data "{\"model\":\"$M\",\"messages\":[{\"role\":\"user\",\"content\":[{\"type\":\"text\",\"text\":\"图里有几个骰子?只回答数字\"},{\"type\":\"image_url\",\"image_url\":{\"url\":\"$IMG\"}}]}],\"max_tokens\":200}" \
 | python3 -c "
import json,sys
raw=sys.stdin.read()
try:
 d=json.loads(raw); c=d['choices'][0]['message']
 print('ANS:',(c.get('content') or '')[:200])
except Exception as e:
 print('ERR/NO-VISION:', raw[:200])
"
done
echo DONE
