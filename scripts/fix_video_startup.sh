#!/bin/bash
cd /root/coze-studio/tool-proxy

echo "=== Step 1: Check container status ==="
docker ps -a | grep tool-proxy

echo ""
echo "=== Step 2: Check container logs for errors ==="
docker logs tool-proxy --tail 30 2>&1

echo ""
echo "=== Step 3: Check syntax ==="
docker exec tool-proxy python3 -c "compile(open('/app/server.py').read(), 'server.py', 'exec'); print('Syntax OK')" 2>&1 || echo "Syntax check failed"

echo ""
echo "=== Step 4: If syntax error, show it ==="
# Try to run python directly
docker exec tool-proxy python3 -c "
try:
    compile(open('/app/server.py').read(), 'server.py', 'exec')
    print('Syntax: OK')
except SyntaxError as e:
    print(f'SYNTAX ERROR at line {e.lineno}: {e.msg}')
    # Show surrounding lines
    lines = open('/app/server.py').readlines()
    start = max(0, e.lineno-3)
    end = min(len(lines), e.lineno+3)
    for i in range(start, end):
        marker = '>>>' if i == e.lineno-1 else '   '
        print(f'{marker} {i+1}: {lines[i].rstrip()}')
"

echo ""
echo "=== Step 5: Try to restart ==="
docker restart tool-proxy
sleep 10
docker ps | grep tool-proxy
docker logs tool-proxy --tail 10 2>&1

echo "[DONE]"
