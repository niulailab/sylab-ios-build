#!/bin/bash
echo "=== sandbox url env in tool-proxy ==="
docker exec tool-proxy sh -c 'echo $SANDBOX_API_URL'
echo "=== containers listening / named sandbox ==="
docker ps --format '{{.Names}}\t{{.Image}}\t{{.Ports}}' | grep -iE "sandbox|9097|runner|node"
echo "=== all container ports 9097 ==="
for c in $(docker ps --format '{{.Names}}'); do
 p=$(docker port "$c" 2>/dev/null | grep -o "9097")
 [ -n "$p" ] && echo "9097 -> $c"
done
echo "=== host process on 9097 ==="
ss -ltnp 2>/dev/null | grep 9097 || true
echo "[DONE]"
