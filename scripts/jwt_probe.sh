#!/bin/bash
echo "=== login ==="
RESP=$(curl -s -X POST http://127.0.0.1:9091/api/passport/web/email/login/ \
 -H "Content-Type: application/json" \
 -d '{"email":"sylab_test@sylab.ai","password":"VK4DxMi0giMQAE5Xpyqo"}')
echo "$RESP" | head -c 500
echo ""
SK=$(echo "$RESP" | python3 -c "import json,sys;d=json.load(sys.stdin);print(d.get('data',{}).get('session_key',''))" 2>/dev/null)
echo "session_key prefix: ${SK:0:30}"
echo ""
echo "=== decode JWT payload (no verify) ==="
python3 - "$SK" <<'PY'
import sys,base64,json
sk=sys.argv[1]
parts=sk.split('.')
print("segments:",len(parts))
if len(parts)>=2:
    p=parts[1]
    p+='='*(-len(p)%4)
    try:
        print(json.dumps(json.loads(base64.urlsafe_b64decode(p)),ensure_ascii=False,indent=2))
    except Exception as e:
        print("decode err",e)
PY
