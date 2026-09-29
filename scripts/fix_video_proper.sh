#!/bin/bash
cd /root/coze-studio/tool-proxy

# Restore from backup
BACKUP=$(ls -t server.py.bak.* | head -1)
echo "=== Step 1: Restore from $BACKUP ==="
cp "$BACKUP" server.py

# Verify restored
python3 -c "compile(open('server.py').read(), 'server.py', 'exec'); print('Syntax OK after restore')"

echo ""
echo "=== Step 2: Show exact return lines in v2 functions (to fix manually) ==="
echo "--- video_generate_v2 returns ---"
grep -n "return.*\"data\"" server.py | awk -F: '$1>=5432' | head -20

echo ""
echo "--- video_status_v2 returns ---"
# Find video_status_v2 line number
STATUS_LINE=$(grep -n "async def video_status_v2" server.py | head -1 | cut -d: -f1)
echo "video_status_v2 starts at line $STATUS_LINE"
grep -n "return.*\"data\"" server.py | awk -F: -v sl="$STATUS_LINE" '$1>=sl' | head -20

echo ""
echo "=== Step 3: Apply proper fix with sed ==="
# Fix approach: use sed to add json.dumps around data dicts
# We need to carefully replace "data":{...}} patterns

# Better approach: use Python with proper brace matching
python3 << 'PYFIX'
import json

with open('server.py', 'r') as f:
    lines = f.readlines()

# Find v2 function boundaries
v2_gen_start = None
v2_gen_end = None
v2_stat_start = None
v2_stat_end = None

for i, line in enumerate(lines):
    if 'async def video_generate_v2' in line:
        v2_gen_start = i
    elif 'async def _poll_and_callback' in line and v2_gen_start is not None:
        v2_gen_end = i
    elif 'async def video_status_v2' in line:
        v2_stat_start = i
    elif 'async def video_content_v2' in line or '@app.api_route' in line:
        if v2_stat_start is not None and v2_stat_end is None:
            v2_stat_end = i

print(f"video_generate_v2: lines {v2_gen_start+1}-{v2_gen_end}")
print(f"video_status_v2: lines {v2_stat_start+1}-{v2_stat_end}")

def fix_return_data(lines, start, end):
    """Fix return statements where data is a dict -> make it json.dumps(dict)"""
    fixed = 0
    for i in range(start, min(end, len(lines))):
        line = lines[i]
        if 'return' not in line or '"data":{' not in line:
            continue
        
        # Find "data":{ in the line
        idx = line.find('"data":{')
        if idx < 0:
            continue
        
        # Find the start of the dict (the { after "data":)
        dict_start = idx + 7  # position of opening {
        
        # Find matching closing }
        depth = 0
        dict_end = -1
        for j in range(dict_start, len(line)):
            if line[j] == '{':
                depth += 1
            elif line[j] == '}':
                depth -= 1
                if depth == 0:
                    dict_end = j
                    break
        
        if dict_end < 0:
            print(f"  Line {i+1}: Could not find matching brace, skipping")
            continue
        
        # Extract the dict content
        dict_content = line[dict_start:dict_end+1]
        
        # Replace with json.dumps(dict_content, ensure_ascii=False)
        before = line[:dict_start]
        after = line[dict_end+1:]
        new_line = before + 'json.dumps(' + dict_content + ', ensure_ascii=False)' + after
        lines[i] = new_line
        fixed += 1
        print(f"  Fixed line {i+1}")
        print(f"    Before: ...{line[idx:idx+80]}...")
        print(f"    After:  ...{new_line[idx:idx+80]}...")
    
    return fixed

# Fix both functions
total = 0
if v2_gen_start and v2_gen_end:
    print("\nFixing video_generate_v2:")
    total += fix_return_data(lines, v2_gen_start, v2_gen_end)
if v2_stat_start and v2_stat_end:
    print("\nFixing video_status_v2:")
    total += fix_return_data(lines, v2_stat_start, v2_stat_end)

with open('server.py', 'w') as f:
    f.writelines(lines)

print(f"\nTotal fixes: {total}")

# Verify syntax
try:
    compile(open('server.py').read(), 'server.py', 'exec')
    print("✅ Syntax check: PASS")
except SyntaxError as e:
    print(f"❌ Syntax error: {e}")
PYFIX

echo ""
echo "=== Step 4: Verify the fixed lines ==="
grep -n "json.dumps.*data\|data.*json.dumps" server.py | grep -E "5[4-9][0-9][0-9]" | head -20

echo ""
echo "=== Step 5: Restart and test ==="
docker restart tool-proxy
sleep 8

# Check if container is running
docker ps | grep tool-proxy

# Show startup logs
docker logs tool-proxy --tail 10 2>&1

# Test inside container
docker exec tool-proxy python3 -c "
import urllib.request, json
req = urllib.request.Request(
    'http://localhost:5435/video/generate',
    data=json.dumps({'action':'quote','duration':5,'prompt':'test cat walking'}).encode(),
    headers={'Content-Type':'application/json','X-Aiplugin-Connector-Identifier':'test_user_quote'}
)
try:
    resp = urllib.request.urlopen(req, timeout=30)
    body = resp.read().decode()
    data = json.loads(body)
    print(f'Status: {resp.status}')
    print(f'code type: {type(data.get(\"code\")).__name__} = {data.get(\"code\")}')
    print(f'msg type: {type(data.get(\"msg\")).__name__} = {data.get(\"msg\")}')
    print(f'data type: {type(data.get(\"data\")).__name__}')
    if isinstance(data.get('data'), str):
        inner = json.loads(data['data'])
        print(f'data keys: {list(inner.keys())}')
        print('✅ FIX VERIFIED: data field is a JSON string!')
    else:
        print(f'❌ Still broken: data is {type(data.get(\"data\")).__name__}')
except Exception as e:
    print(f'Error: {e}')
"

echo "[DONE]"
