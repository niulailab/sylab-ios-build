#!/bin/bash
cd /root/coze-studio/tool-proxy

# Backup first
cp server.py server.py.bak.$(date +%s)

echo "=== Step 1: Find all return statements in video_generate_v2 that have data as dict ==="
grep -n '"data":' server.py | grep -n "5[0-9][0-9][0-9]\|5[0-9][0-9][0-9]" | head -30
# Better approach: just look at all return lines in the v2 function range
echo ""
echo "=== Lines with data: dict in v2 function (lines 5432+) ==="
awk 'NR>=5432 && /return.*"data":\{/' server.py | head -20

echo ""
echo "=== Step 2: Apply fix - make data a JSON string ==="
# The fix: in video_generate_v2, replace all `"data":{...}` with `"data":json.dumps({...})`
# But that's complex with sed. Better approach: use Python to do the replacement.

python3 << 'PYFIX'
import re

with open('server.py', 'r') as f:
    content = f.read()

# Find the video_generate_v2 function and fix its return statements
# Strategy: replace "data":{...} with "data":json.dumps({...}) in v2 function returns

# The v2 function starts around line 5432
lines = content.split('\n')
in_v2_generate = False
in_v2_status = False
v2_start = 0
fixes = 0

for i, line in enumerate(lines):
    # Track if we're in v2 function
    if 'async def video_generate_v2' in line:
        in_v2_generate = True
        in_v2_status = False
        v2_start = i
        print(f"Found video_generate_v2 at line {i+1}")
    elif 'async def video_status_v2' in line:
        in_v2_generate = False
        in_v2_status = True
        v2_start = i
        print(f"Found video_status_v2 at line {i+1}")
    elif 'async def ' in line and in_v2_generate:
        in_v2_generate = False
    elif 'async def ' in line and in_v2_status:
        in_v2_status = False
    elif '_replace_route' in line:
        in_v2_generate = False
        in_v2_status = False
    
    if (in_v2_generate or in_v2_status) and '"data":{' in line and 'return' in line:
        # This is a return statement with data as dict - needs fixing
        # Strategy: wrap the dict value with _j() helper
        # Replace "data":{...}} with "data":_j({...})
        # But we need to be careful about matching braces
        
        # Simple approach: use a regex to find "data":{...} and wrap it
        # Since these are return statements, the dict is the last arg
        
        # Find the position of "data":{ in the line
        idx = line.find('"data":{')
        if idx >= 0:
            # Find the matching closing brace
            start = idx + 7  # position of {
            depth = 0
            end = start
            for j in range(start, len(line)):
                if line[j] == '{':
                    depth += 1
                elif line[j] == '}':
                    depth -= 1
                    if depth == 0:
                        end = j
                        break
            
            dict_str = line[start:end+1]
            # Replace with _j(dict_str)
            new_line = line[:start] + '_j(' + dict_str + ')' + line[end+1:]
            lines[i] = new_line
            fixes += 1
            print(f"Fixed line {i+1}: data dict -> _j(dict)")
            print(f"  Old: {line.strip()[:100]}")
            print(f"  New: {new_line.strip()[:100]}")

# Also add the _j helper function if it doesn't exist
if '_j=' not in content and 'def _j(' not in content:
    # Add helper at the top of the file (after imports)
    # Find a good insertion point - after the last import
    for i, line in enumerate(lines):
        if line.startswith('import json') or line.startswith('import logging'):
            insert_at = i + 1
    lines.insert(insert_at, '_j = json.dumps  # serialize data field to string for framework compatibility')
    print(f"\nAdded _j helper at line {insert_at+1}")

with open('server.py', 'w') as f:
    f.write('\n'.join(lines))

print(f"\nTotal fixes: {fixes}")
PYFIX

echo ""
echo "=== Step 3: Verify the fix ==="
# Check that data is now serialized
grep -n '"data":' server.py | grep -E "_j\(|json\.dumps" | tail -20
echo ""
echo "=== Lines that still have data:{ (should be none in v2 function) ==="
awk 'NR>=5432 && /return.*"data":\{/' server.py | head -10

echo ""
echo "=== Step 4: Restart tool-proxy ==="
docker restart tool-proxy
sleep 5
docker logs tool-proxy --tail 5 2>&1

echo ""
echo "=== Step 5: Test the fix ==="
# Test inside the container
docker exec tool-proxy python3 -c "
import urllib.request, json
req = urllib.request.Request(
    'http://localhost:5435/video/generate',
    data=json.dumps({'action':'quote','duration':5,'prompt':'test cat walking'}).encode(),
    headers={'Content-Type':'application/json','X-Aiplugin-Connector-Identifier':'test_user'}
)
try:
    resp = urllib.request.urlopen(req, timeout=30)
    body = resp.read().decode()
    print(f'Status: {resp.status}')
    data = json.loads(body)
    print(f'code: {data.get(\"code\")} (type: {type(data.get(\"code\")).__name__})')
    print(f'msg: {data.get(\"msg\")} (type: {type(data.get(\"msg\")).__name__})')
    print(f'data: {str(data.get(\"data\"))[:200]} (type: {type(data.get(\"data\")).__name__})')
    # Check if data is a string (this is the fix!)
    if isinstance(data.get('data'), str):
        print('✅ FIX VERIFIED: data is now a string!')
        inner = json.loads(data['data'])
        print(f'Inner data keys: {list(inner.keys())}')
    else:
        print('❌ FIX NOT WORKING: data is still a dict')
except Exception as e:
    print(f'Error: {e}')
"

echo "[DONE]"
