#!/bin/bash
SC=coze-server
echo "=== config files mentioning model/llm/host ==="
docker exec "$SC" sh -lc "ls -la /app/conf 2>/dev/null; ls /app 2>/dev/null"
echo "=== grep env/config for model hosts ==="
docker exec "$SC" sh -lc "env | grep -iE 'model|llm|bigmodel|tool-proxy|9092|9093|proxy|openai' | head -40"
echo "=== llm-proxy exists? ==="
docker ps --format '{{.Names}} {{.Image}} {{.Ports}}' | grep -iE 'proxy|llm'
echo DONE
