#!/bin/bash
echo "=== decode stored session_key for owner (structure only) ==="
docker exec coze-mysql mysql -uroot -pd3G8JG273iE8C4irRWJX opencoze -N -e \
 "select session_key from user where id=7666848996043784192;" 2>/dev/null > /tmp/sk.txt
python3 <<'PY'
sk=open('/tmp/sk.txt').read().strip()
print("len:",len(sk),"segs:",len(sk.split('.')),"prefix:",sk[:20])
import base64,json
p=sk.split('.')
if len(p)>=2:
    b=p[1]+'='*(-len(p[1])%4)
    try:
        d=json.loads(base64.urlsafe_b64decode(b))
        # mask anything that looks secret, show keys + uid-ish
        print("payload keys:",list(d.keys()))
        for k,v in d.items():
            if any(x in k.lower() for x in ('id','sub','uid','user','open','exp','iat','name')):
                print(f"  {k} = {v}")
    except Exception as e: print("err",e)
PY
echo ""
echo "=== and test account (sylab_test) ==="
docker exec coze-mysql mysql -uroot -pd3G8JG273iE8C4irRWJX opencoze -N -e \
 "select session_key from user where id=17857736066221234;" 2>/dev/null > /tmp/sk2.txt
python3 <<'PY'
sk=open('/tmp/sk2.txt').read().strip()
print("len:",len(sk),"segs:",len(sk.split('.')))
if len(sk.split('.'))>=2:
    import base64,json
    b=sk.split('.')[1]; b+='='*(-len(b)%4)
    try:
        d=json.loads(base64.urlsafe_b64decode(b))
        print("keys:",list(d.keys()))
        for k,v in d.items():
            if any(x in k.lower() for x in ('id','sub','uid','user','open','exp')): print(f"  {k}={v}")
    except Exception as e: print("err",e)
PY
