#!/bin/bash
cd /root/coze-studio/tool-proxy

echo "=== Step 1: First send quotes for 4 concurrent tasks ==="
docker exec tool-proxy python3 << 'PYEOF'
import urllib.request, json, concurrent.futures

def quote(prompt_id):
    """Send a quote request"""
    req = urllib.request.Request(
        'http://localhost:9092/video/generate',
        data=json.dumps({'action':'quote','duration':5,'prompt':f'concurrent test scene {prompt_id}'}).encode(),
        headers={'Content-Type':'application/json','X-Aiplugin-Connector-Identifier':'concurrent_test_user'}
    )
    resp = urllib.request.urlopen(req, timeout=30)
    data = json.loads(resp.read().decode())
    return prompt_id, data

# Send 4 concurrent quotes
with concurrent.futures.ThreadPoolExecutor(max_workers=4) as executor:
    results = list(executor.map(quote, range(4)))

for pid, data in results:
    assert isinstance(data['data'], str), f'quote {pid}: data not string'
    inner = json.loads(data['data'])
    print(f"✅ quote {pid}: cost={inner['cost']}, action={inner['action']}")

print("\nAll 4 concurrent quotes succeeded.")
PYEOF

echo ""
echo "=== Step 2: Now test 4 concurrent GENERATE calls ==="
docker exec tool-proxy python3 << 'PYEOF'
import urllib.request, json, concurrent.futures, time

def generate(prompt_id):
    """Send a generate request"""
    prompts = [
        "a beautiful girl dancing in hanfu in a garden",
        "a young woman walking through an ancient city street",
        "a girl playing a traditional instrument under moonlight",
        "a princess spinning gracefully in a palace hall"
    ]
    req = urllib.request.Request(
        'http://localhost:9092/video/generate',
        data=json.dumps({
            'action':'generate',
            'duration':5,
            'prompt': prompts[prompt_id] + f' scene{prompt_id}_{int(time.time())}'
        }).encode(),
        headers={'Content-Type':'application/json','X-Aiplugin-Connector-Identifier':'concurrent_test_user'}
    )
    try:
        resp = urllib.request.urlopen(req, timeout=60)
        data = json.loads(resp.read().decode())
        return prompt_id, data, None
    except Exception as e:
        return prompt_id, None, str(e)

# Send 4 concurrent generate requests simultaneously
print("Sending 4 concurrent generate requests...")
t0 = time.time()
with concurrent.futures.ThreadPoolExecutor(max_workers=4) as executor:
    results = list(executor.map(generate, range(4)))
elapsed = time.time() - t0
print(f"All responses received in {elapsed:.1f}s\n")

task_ids = []
for pid, data, err in results:
    if err:
        print(f"❌ task {pid}: ERROR: {err}")
        continue
    
    code = data.get('code')
    raw_data = data.get('data')
    
    if not isinstance(raw_data, str):
        print(f"❌ task {pid}: data is {type(raw_data).__name__}, not string! raw={str(raw_data)[:100]}")
        continue
    
    inner = json.loads(raw_data)
    tid = inner.get('task_id')
    status = inner.get('status')
    cost = inner.get('cost')
    balance = inner.get('balance')
    
    if tid:
        task_ids.append(tid)
        print(f"✅ task {pid}: task_id={tid}, status={status}, cost={cost}, balance={balance}")
    else:
        print(f"⚠️  task {pid}: no task_id, code={code}, msg={data.get('msg')}, inner={inner}")

print(f"\n=== Summary ===")
print(f"Concurrent requests: 4")
print(f"Successful task_ids: {len(task_ids)}/4")
print(f"All task_ids unique: {len(set(task_ids)) == len(task_ids) and len(task_ids) > 0}")
if len(task_ids) == 4:
    print("\n🎉 CONCURRENT GENERATION WORKS PERFECTLY!")
else:
    print(f"\n⚠️  {4-len(task_ids)} task(s) failed")

# Save task IDs for status check
with open('/tmp/concurrent_task_ids.json','w') as f:
    json.dump(task_ids, f)
PYEOF

echo ""
echo "=== Step 3: Check backend logs for all 4 submissions ==="
docker logs tool-proxy --since 2m 2>&1 | grep "\[VID\] submit" | tail -10

echo ""
echo "=== Step 4: Immediately check status of all 4 tasks concurrently ==="
docker exec tool-proxy python3 << 'PYEOF'
import urllib.request, json, concurrent.futures

with open('/tmp/concurrent_task_ids.json') as f:
    task_ids = json.load(f)

def check_status(tid):
    req = urllib.request.Request(
        f'http://localhost:9092/video/status/{tid}',
        headers={'X-Aiplugin-Connector-Identifier':'concurrent_test_user'}
    )
    resp = urllib.request.urlopen(req, timeout=30)
    data = json.loads(resp.read().decode())
    return tid, data

print(f"Checking {len(task_ids)} tasks concurrently...")
with concurrent.futures.ThreadPoolExecutor(max_workers=4) as executor:
    results = list(executor.map(check_status, task_ids))

for tid, data in results:
    assert isinstance(data['data'], str), f'status data not string for {tid}'
    inner = json.loads(data['data'])
    print(f"  task {tid}: status={inner.get('status')}, progress={inner.get('progress')}%, url={'yes' if inner.get('video_url') else 'pending'}")

print("\n✅ Concurrent status checks all returned string data correctly!")
PYEOF

echo "[DONE]"
