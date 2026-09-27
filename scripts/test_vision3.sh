#!/bin/bash
KEY="sk-bb71bcccb3854dab839ed20c2439d7709c3a75dff8080712"
IMG="https://upload.wikimedia.org/wikipedia/commons/thumb/4/47/PNG_transparency_demonstration_1.png/320px-PNG_transparency_demonstration_1.png"
for M in glm-5.2 deepseek-v4-pro; do
echo "===== $M retry vision ====="
curl -s -m 90 "https://laneai.dev/v1/chat/completions" -H "Authorization: Bearer $KEY" -H "Content-Type: application/json" --data "{\"model\":\"$M\",\"messages\":[{\"role\":\"user\",\"content\":[{\"type\":\"text\",\"text\":\"请仔细看这张图,描述你看到的物体和数量。\"},{\"type\":\"image_url\",\"image_url\":{\"url\":\"$IMG\"}}]}],\"max_tokens\":400}" \
 | python3 -c "
import json,sys
raw=sys.stdin.read()
try:
 d=json.loads(raw); print('ANS:',(d['choices'][0]['message'].get('content') or '')[:400])
except Exception as e:
 print('ERR:', raw[:300])
"
done
echo DONE
