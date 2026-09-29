#!/bin/bash
cd /root/coze-studio/tool-proxy

echo "=== Step 1: Show exact quote return lines ==="
grep -n '"data":{"action":"quote"' server.py

echo ""
echo "=== Step 2: Fix the quote return ==="
# Show exact lines
LINE=$(grep -n '"data":{"action":"quote"' server.py | head -1 | cut -d: -f1)
echo "Quote return at line $LINE"
sed -n "${LINE},$((LINE+6))p" server.py

echo ""
# Use sed to replace data:{ with data:json.dumps({ on the specific line
# and add }, ensure_ascii=False) before the closing }}
# Actually, the multi-line dict ends with }} on a later line.
# Let me use Python for this specific fix

python3 << 'PYFIX'
with open('server.py', 'r') as f:
    lines = f.readlines()

for i, line in enumerate(lines):
    if '"data":{"action":"quote"' in line:
        print(f"Found at line {i+1}: {line.strip()[:100]}")
        # Find the closing }}
        for j in range(i, min(i+10, len(lines))):
            if '"}}' in lines[j]:
                print(f"Closes at line {j+1}: {lines[j].strip()[:100]}")
                # Fix: change data:{ to data:json.dumps({
                lines[i] = lines[i].replace('"data":{', '"data":json.dumps({')
                # Fix: change "}} to }, ensure_ascii=False)}
                lines[j] = lines[j].replace('"}}', '}, ensure_ascii=False)}')
                print(f"Fixed both lines")
                break
        break

with open('server.py', 'w') as f:
    f.writelines(lines)

compile(open('server.py').read(), 'server.py', 'exec')
print("✅ Syntax OK")
PYFIX

echo ""
echo "=== Step 3: Verify no more data:{ in v2 range ==="
awk 'NR>=5432 && NR<=5590 && /"data":\{/ && !/json\.dumps/' server.py
echo "(should be empty)"

echo ""
echo "=== Step 4: Restart and test ==="
docker restart tool-proxy
sleep 8

docker exec tool-proxy python3 -c "
import urllib.request, json

# Test quote
req = urllib.request.Request(
    'http://localhost:9092/video/generate',
    data=json.dumps({'action':'quote','duration':5,'prompt':'test'}).encode(),
    headers={'Content-Type':'application/json','X-Aiplugin-Connector-Identifier':'test_final'}
)
resp = urllib.request.urlopen(req, timeout=30)
data = json.loads(resp.read().decode())
assert isinstance(data['data'], str), f'data should be str, got {type(data[\"data\"])}'
inner = json.loads(data['data'])
assert 'action' in inner and inner['action'] == 'quote'
assert 'cost' in inner and 'hint' in inner
print('✅ quote: data is string, inner has action/cost/hint')
print(f'   cost={inner[\"cost\"]} credits, duration={inner[\"duration\"]}')

# Test error case (no recent quote -> generate should fail gracefully)
req2 = urllib.request.Request(
    'http://localhost:9092/video/generate',
    data=json.dumps({'action':'generate','duration':5,'prompt':'test'}).encode(),
    headers={'Content-Type':'application/json','X-Aiplugin-Connector-Identifier':'test_no_quote'}
)
resp2 = urllib.request.urlopen(req2, timeout=30)
data2 = json.loads(resp2.read().decode())
assert data2['code'] == 1, f'expected code=1, got {data2[\"code\"]}'
print(f'✅ no-quote error: code=1, msg={data2[\"msg\"]}')

print()
print('🎉 ALL TESTS PASSED - video_generate is fixed!')
"

echo "[DONE]"
