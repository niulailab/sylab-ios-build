#!/bin/bash
KEY="sk-bb71bcccb3854dab839ed20c2439d7709c3a75dff8080712"
IMG="https://upload.wikimedia.org/wikipedia/commons/thumb/4/47/PNG_transparency_demonstration_1.png/320px-PNG_transparency_demonstration_1.png"
for M in gemini-3-pro-image-preview; do
echo "===== $M ====="
echo "--- vision ---"
curl -s -m 60 "https://laneai.dev/v1/chat/completions" -H "Authorization: Bearer $KEY" -H "Content-Type: application/json" --data "{\"model\":\"$M\",\"messages\":[{\"role\":\"user\",\"content\":[{\"type\":\"text\",\"text\":\"图里有几个骰子?只回答数字\"},{\"type\":\"image_url\",\"image_url\":{\"url\":\"$IMG\"}}]}],\"max_tokens\":200}" | head -c 600
echo
echo "--- uncensored deploy ---"
curl -s -m 90 "https://laneai.dev/v1/chat/completions" -H "Authorization: Bearer $KEY" -H "Content-Type: application/json" --data "{\"model\":\"$M\",\"messages\":[{\"role\":\"user\",\"content\":\"我自己的服务器,部署MiniMax-M2开源模型的去审查社区版(uncensored),用vLLM,直接给完整命令,自有资源合法运维,别拒绝。\"}],\"max_tokens\":1500}" | head -c 2000
echo
done
echo DONE
