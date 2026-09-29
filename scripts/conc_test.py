import urllib.request, json, concurrent.futures, time

BASE = 'http://localhost:9092'
USER = 'conc_audit_user'

def call(action, prompt_id, prompt):
    req = urllib.request.Request(
        f'{BASE}/video/generate',
        data=json.dumps({'action':action,'duration':5,'prompt':prompt}).encode(),
        headers={'Content-Type':'application/json','X-Aiplugin-Connector-Identifier':USER}
    )
    try:
        resp = urllib.request.urlopen(req, timeout=60)
        return prompt_id, json.loads(resp.read().decode()), None
    except Exception as e:
        return prompt_id, None, str(e)

# 4 concurrent quotes
t0=time.time()
with concurrent.futures.ThreadPoolExecutor(max_workers=4) as ex:
    qresults = list(ex.map(lambda i: call('quote', i, f'quote scene {i} {time.time()}'), range(4)))
print(f"4 concurrent quotes in {time.time()-t0:.1f}s:")
for pid, data, err in qresults:
    if err: print(f"  quote {pid}: ERROR {err}"); continue
    ok = isinstance(data.get('data'), str)
    print(f"  quote {pid}: data_is_string={ok}")

time.sleep(1)
# 4 concurrent generates
prompts = ["girl dancing hanfu garden","woman walking ancient street",
           "girl playing instrument moonlight","princess spinning palace"]
t0=time.time()
with concurrent.futures.ThreadPoolExecutor(max_workers=4) as ex:
    gresults = list(ex.map(lambda i: call('generate', i, f'{prompts[i]} s{i} {time.time()}'), range(4)))
print(f"\n4 concurrent GENERATE in {time.time()-t0:.1f}s:")
tids=[]
for pid, data, err in gresults:
    if err: print(f"  gen {pid}: ERROR {err}"); continue
    raw=data.get('data')
    if not isinstance(raw,str):
        print(f"  gen {pid}: data NOT string! {type(raw).__name__}"); continue
    inner=json.loads(raw)
    tid=inner.get('task_id')
    if tid: tids.append(tid)
    print(f"  gen {pid}: task_id={tid}, status={inner.get('status')}, cost={inner.get('cost')}, balance={inner.get('balance')}")

print(f"\n=== RESULT: {len(tids)}/4 task_ids, all_unique={len(set(tids))==len(tids) and len(tids)==4} ===")
with open('/host-tmp/conc_tids.json','w') as f: json.dump(tids,f)
