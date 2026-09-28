#!/bin/bash
echo "=== running containers ==="
docker ps --format '{{.Names}}\t{{.Image}}\t{{.Status}}' | grep -iE "code|exec|runner|iso" 
echo "=== all containers (incl stopped) ==="
docker ps -a --format '{{.Names}}\t{{.Status}}' | grep -iE "code|exec|runner|iso"
echo "=== networks ==="
docker network ls | grep -iE "code|iso"
echo "=== br-codeiso detail ==="
docker network inspect br-codeiso --format '{{.Name}} {{.Driver}} {{range .Containers}}{{.Name}} {{end}}' 2>/dev/null
echo "[DONE]"
