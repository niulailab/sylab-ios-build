#!/bin/bash
echo "=== docker ps (llm-ish) ==="
docker ps --format '{{.Names}}\t{{.Ports}}' | grep -Ei 'ollama|vllm|llm|qwen|xinference|lmdeploy|webui|sglang' || echo none
echo "=== listening ports ==="
ss -ltnp 2>/dev/null | grep -E ':8000|:11434|:8080|:1234|:9997|:3000|:4000|:5000|:5001|:8001' || echo none
echo "=== curl local probes ==="
for p in 11434 8000 1234 9997 8001; do
  r=$(curl -s -m 2 "http://127.0.0.1:$p/v1/models" 2>/dev/null | head -c 200)
  [ -n "$r" ] && echo "port $p: $r"
done
echo DONE
