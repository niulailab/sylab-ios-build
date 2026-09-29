#!/bin/bash
cd /root/coze-studio/tool-proxy

echo "=== Step 1: Show the unfixed multi-line returns ==="
echo "--- Line 5463 area (quote response) ---"
sed -n '5460,5470p' server.py
echo ""
echo "--- Line 5486 area (success after submit) ---"
sed -n '5483,5492p' server.py
echo ""
echo "--- Line 5554 area (status unknown) ---"
sed -n '5550,5560p' server.py
echo ""
echo "--- Line 5565 area (status completed) ---"
sed -n '5562,5572p' server.py

echo ""
echo "=== Step 2: Fix multi-line returns with Python ==="
python3 << 'PYFIX'
with open('server.py', 'r') as f:
    content = f.read()

# Fix 1: quote response (around line 5463)
# Original: return {"code":0,"msg":"success","data":{
#     "action":"quote",...
# }}
# Fix: wrap the inner dict with json.dumps

old_quote = '''return {"code":0,"msg":"success","data":{
            "action":"quote","tier":tier,"model":f"h3-{tier}",
            "quality":cfg["label"],"duration":f"{duration}秒","resolution":ratio.split(" (")[0],
            "cost":cost,"credits_per_sec":cfg["credits_per_sec"],
            "description":f"{cfg['label']}H3 视频 {duration}秒，{cost}积分（{cfg['credits_per_sec']}积分/秒），自动套用 H3 导演脚本，预计 1-8 分钟。",
            "hint":"请把报价告诉用户并确认。确认后必须再次调用 video_generate(action=generate, 相同 prompt/tier/duration) 实际生成，不要只回文字。"}}'''

new_quote = '''return {"code":0,"msg":"success","data":json.dumps({
            "action":"quote","tier":tier,"model":f"h3-{tier}",
            "quality":cfg["label"],"duration":f"{duration}秒","resolution":ratio.split(" (")[0],
            "cost":cost,"credits_per_sec":cfg["credits_per_sec"],
            "description":f"{cfg['label']}H3 视频 {duration}秒，{cost}积分（{cfg['credits_per_sec']}积分/秒），自动套用 H3 导演脚本，预计 1-8 分钟。",
            "hint":"请把报价告诉用户并确认。确认后必须再次调用 video_generate(action=generate, 相同 prompt/tier/duration) 实际生成，不要只回文字。"}, ensure_ascii=False)}'''

if old_quote in content:
    content = content.replace(old_quote, new_quote)
    print("✅ Fixed quote response")
else:
    print("❌ Could not find quote response pattern")

# Fix 2: success response after submit (around line 5486-5489)
old_success = '''return {"code":0,"msg":"success","data":{"task_id":tid,"status":"processing","tier":tier,
        "quality":cfg["label"],"model":f"h3-{tier}","duration":duration,"cost":cost,"balance":bal,
        "hint":"视频生成中，预计 1-8 分钟。完成后会自动通知你。"}}'''

new_success = '''return {"code":0,"msg":"success","data":json.dumps({"task_id":tid,"status":"processing","tier":tier,
        "quality":cfg["label"],"model":f"h3-{tier}","duration":duration,"cost":cost,"balance":bal,
        "hint":"视频生成中，预计 1-8 分钟。完成后会自动通知你。"}, ensure_ascii=False)}'''

if old_success in content:
    content = content.replace(old_success, new_success)
    print("✅ Fixed success response")
else:
    print("❌ Could not find success response pattern")

# Fix 3: status unknown response (around line 5554)
old_unknown = '''return {"code":0,"msg":"success","data":{"task_id":task_id,"status":rec.get("status","unknown"),
            "progress":0,"video_url":rec.get("video_url","")}}'''

new_unknown = '''return {"code":0,"msg":"success","data":json.dumps({"task_id":task_id,"status":rec.get("status","unknown"),
            "progress":0,"video_url":rec.get("video_url","")}, ensure_ascii=False)}'''

if old_unknown in content:
    content = content.replace(old_unknown, new_unknown)
    print("✅ Fixed status unknown response")
else:
    print("❌ Could not find status unknown pattern")

# Fix 4: status completed response (around line 5565)
old_completed = '''return {"code":0,"msg":"success","data":{"task_id":task_id,"status":"completed","progress":100,
            "video_url":out,"tier":rec.get("tier"),"cost":rec.get("cost"),"balance":None}}'''

new_completed = '''return {"code":0,"msg":"success","data":json.dumps({"task_id":task_id,"status":"completed","progress":100,
            "video_url":out,"tier":rec.get("tier"),"cost":rec.get("cost"),"balance":None}, ensure_ascii=False)}'''

if old_completed in content:
    content = content.replace(old_completed, new_completed)
    print("✅ Fixed status completed response")
else:
    print("❌ Could not find status completed pattern")

with open('server.py', 'w') as f:
    f.write(content)

# Verify syntax
try:
    compile(content, 'server.py', 'exec')
    print("✅ Syntax check: PASS")
except SyntaxError as e:
    print(f"❌ Syntax error: {e}")
PYFIX

echo ""
echo "=== Step 3: Verify ALL data: returns in v2 functions are now json.dumps ==="
echo "--- Any remaining data:{ without json.dumps in v2 range? ---"
awk 'NR>=5432 && NR<=5580 && /"data":\{/ && !/json\.dumps/' server.py
echo "(above should be empty)"

echo ""
echo "=== Step 4: Restart and test on correct port ==="
docker restart tool-proxy
sleep 8
docker ps | grep tool-proxy

# Test on port 9092 (correct internal port)
docker exec tool-proxy python3 -c "
import urllib.request, json
req = urllib.request.Request(
    'http://localhost:9092/video/generate',
    data=json.dumps({'action':'quote','duration':5,'prompt':'test cat walking'}).encode(),
    headers={'Content-Type':'application/json','X-Aiplugin-Connector-Identifier':'test_user_final'}
)
try:
    resp = urllib.request.urlopen(req, timeout=30)
    body = resp.read().decode()
    data = json.loads(body)
    print(f'Status: {resp.status}')
    print(f'code: {data.get(\"code\")} ({type(data.get(\"code\")).__name__})')
    print(f'msg: {data.get(\"msg\")} ({type(data.get(\"msg\")).__name__})')
    print(f'data: type={type(data.get(\"data\")).__name__}')
    if isinstance(data.get('data'), str):
        inner = json.loads(data['data'])
        print(f'data keys: {list(inner.keys())}')
        print(f'data content: {json.dumps(inner, ensure_ascii=False)[:200]}')
        print('')
        print('✅✅✅ FIX VERIFIED ✅✅✅')
        print('data field is now a JSON string - sylab framework will parse it correctly!')
    else:
        print(f'❌ Still broken: data is {type(data.get(\"data\")).__name__}')
except Exception as e:
    print(f'Error: {e}')
"

echo "[DONE]"
