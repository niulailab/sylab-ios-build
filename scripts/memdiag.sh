#!/usr/bin/env bash
echo "== memory-related containers =="
docker ps --format '{{.Names}} | {{.Image}} | {{.Ports}} | {{.Status}}' | grep -iE 'memory|milvus|kg|graph' || echo "NONE_RUNNING"
echo
echo "== all containers (names only) =="
docker ps --format '{{.Names}}' | sort
echo
echo "== probe :8900 openapi paths =="
curl -s --max-time 6 http://127.0.0.1:8900/openapi.json 2>/dev/null \
 | python3 -c "import sys,json
try:
 d=json.load(sys.stdin); ps=sorted(d.get('paths',{}).keys())
 print('PATHS:'); [print(' ',p) for p in ps]
except Exception as e:
 print('no openapi at 8900:',e)"
echo
echo "== probe /kg endpoint directly =="
curl -s --max-time 6 -X POST http://127.0.0.1:8900/kg -H 'Content-Type: application/json' -d '{"action":"status"}' 2>/dev/null | head -c 500; echo
echo
echo "== memory service DB tables (look for entity/relation) =="
find / -name '*.db' 2>/dev/null | grep -iE 'memory|coze' | head
echo DIAG_DONE
