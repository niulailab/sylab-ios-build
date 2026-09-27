#!/bin/bash
echo "=== llm-proxy inspect ==="
docker inspect llm-proxy --format '{{json .Config.Env}}' | python3 -m json.tool 2>/dev/null | head -40
echo "=== llm-proxy network/ports ==="
docker inspect llm-proxy --format '{{json .NetworkSettings.Networks}}' | python3 -m json.tool 2>/dev/null | head -30
echo "=== try models endpoints ==="
for u in "http://llm-proxy:9093/v1/models" "http://127.0.0.1:9093/v1/models"; do
 echo "-- $u"
 curl -s -m 4 "$u" | head -c 800; echo
done
echo DONE
