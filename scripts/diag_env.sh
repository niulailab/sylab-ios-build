#!/bin/bash
cat > /tmp/_ve2.py <<'PY'
import json, urllib.request
code = '''
import os, sys
print("ENV_PP=", repr(os.environ.get("PYTHONPATH")))
print("ENV_FS=", repr(os.environ.get("FILE_SERVICE")))
print("ENV_CONV=", repr(os.environ.get("SANDBOX_CONVERSATION_ID")))
print("sys.path[0:3]=", sys.path[0:3])
try:
    import sitecustomize as sc
    print("SC OK", sc.__file__, hasattr(sc,"upload_file"))
except Exception as e:
    print("SC ERR", repr(e))
'''
payload=json.dumps({"code":code,"language":"python","timeout":40,"session_id":"diag_env_1"}).encode()
req=urllib.request.Request("http://127.0.0.1:9097/execute",data=payload,
    headers={"Content-Type":"application/json"})
print(urllib.request.urlopen(req,timeout=80).read().decode())
PY
python3 /tmp/_ve2.py
echo "[DONE]"
