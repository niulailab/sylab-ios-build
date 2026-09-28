#!/bin/bash
python3 <<'PY'
import base64,json
for f,label in [('/tmp/sk.txt','owner'),('/tmp/sk2.txt','sylab_test')]:
    sk=open(f).read().strip()
    b=sk+'='*(-len(sk)%4)
    print(f"--- {label} ---")
    try:
        d=json.loads(base64.urlsafe_b64decode(b))
        print(json.dumps(d,ensure_ascii=False,indent=2,default=str))
    except Exception as e: print("err",e)
PY
