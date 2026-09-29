#!/bin/bash
cd /root/coze-studio/tool-proxy

echo "=== Step 1: Show the broken lines ==="
sed -n '5460,5470p' server.py

echo ""
echo "=== Step 2: Fix with exact string replacement ==="
python3 << 'PYFIX'
with open('server.py', 'r') as f:
    content = f.read()

# Show the exact broken text
broken = '不要只回文字。}, ensure_ascii=False)}'
if broken in content:
    print(f"Found broken pattern: ...{broken}")
    # Fix: the hint string's closing " was eaten. Restore it.
    # Broken: ..."hint":"...不要只回文字。}, ensure_ascii=False)}
    # Correct: ..."hint":"...不要只回文字。"}, ensure_ascii=False)}
    fixed = '不要只回文字。"}, ensure_ascii=False)}'
    content = content.replace(broken, fixed)
    print(f"Fixed to: ...{fixed}")
else:
    print("Broken pattern not found, trying alternative...")
    # Maybe the actual text is different
    import re
    # Find the line with the hint in the quote response
    lines = content.split('\n')
    for i, line in enumerate(lines):
        if '不要只回文字' in line and 'ensure_ascii' in line:
            print(f"Found at line {i+1}: {line}")
            # Fix this specific line
            # Current: ...文字。}, ensure_ascii=False)}
            # Should:  ...文字。"}, ensure_ascii=False)}
            lines[i] = line.replace('文字。}, ensure_ascii', '文字。"}, ensure_ascii')
            print(f"Fixed to: {lines[i]}")
    content = '\n'.join(lines)

# Also check if data:{ was fixed on the opening line
if '"data":{"action":"quote"' in content:
    # Find it and wrap with json.dumps
    lines = content.split('\n')
    for i, line in enumerate(lines):
        if '"data":{"action":"quote"' in line:
            lines[i] = line.replace('"data":{"action":"quote"', '"data":json.dumps({"action":"quote"')
            print(f"Also fixed opening data:{{ at line {i+1}")
    content = '\n'.join(lines)

with open('server.py', 'w') as f:
    f.write(content)

try:
    compile(content, 'server.py', 'exec')
    print("✅ Syntax check: PASS")
except SyntaxError as e:
    print(f"❌ Syntax error at line {e.lineno}: {e.msg}")
    lines = content.split('\n')
    for j in range(max(0,e.lineno-3), min(len(lines), e.lineno+2)):
        marker = '>>>' if j == e.lineno-1 else '   '
        print(f"{marker} {j+1}: {lines[j]}")
PYFIX

echo ""
echo "=== Step 3: Restart ==="
docker restart tool-proxy
sleep 10
docker ps | grep tool-proxy
docker logs tool-proxy --tail 5 2>&1

echo ""
echo "=== Step 4: Test ==="
docker exec tool-proxy python3 -c "
import urllib.request, json

# Test quote
req = urllib.request.Request(
    'http://localhost:9092/video/generate',
    data=json.dumps({'action':'quote','duration':5,'prompt':'test cat'}).encode(),
    headers={'Content-Type':'application/json','X-Aiplugin-Connector-Identifier':'final_test_user'}
)
resp = urllib.request.urlopen(req, timeout=30)
data = json.loads(resp.read().decode())
assert isinstance(data['data'], str), f'data should be str, got {type(data[\"data\"])}'
inner = json.loads(data['data'])
print(f'✅ quote response OK: action={inner[\"action\"]}, cost={inner[\"cost\"]}, hint present={\"hint\" in inner}')
print(f'   data is json string: {data[\"data\"][:120]}...')
print()
print('🎉 video_generate_v2 is fully fixed!')
"

echo "[DONE]"
