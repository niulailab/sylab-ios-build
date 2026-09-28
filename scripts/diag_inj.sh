#!/bin/bash
echo "=== pyinj dirs ==="
ls -la /tmp/pyinj_* 2>/dev/null | head -20
echo "=== check current executePython in running file ==="
grep -n "sitecustomize\|pyinj\|PYTHONPATH\|FILE_SERVICE\|SANDBOX_CONV" /root/code_exec_server.js | head
echo "=== which pid serves 9097 & cwd ==="
PID=$(ss -ltnp 2>/dev/null | grep ':9097' | grep -oE 'pid=[0-9]+' | head -1 | cut -d= -f2)
echo pid=$PID
ls -l /proc/$PID/cwd
tr '\0' '\n' < /proc/$PID/cmdline
echo "=== manually simulate env load ==="
cat > /tmp/_t.py <<'PY'
import sys, os
print("PYTHONPATH=",os.environ.get("PYTHONPATH"))
try:
 import sitecustomize
 print("sitecustomize loaded from", sitecustomize.__file__)
 print("has upload_file", hasattr(sitecustomize,"upload_file"))
except Exception as e:
 print("sitecustomize ERR", repr(e))
PY
INJ=$(ls -d /tmp/pyinj_* 2>/dev/null | head -1)
echo "using INJ=$INJ"
PYTHONPATH="$INJ" python3 /tmp/_t.py
echo "[DONE]"
