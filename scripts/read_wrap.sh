#!/bin/bash
echo "=== search wrapping of python code ==="
grep -nE "<workspace>|run_path|exec\(|__sandbox|wrap|-S\b|site.main|no-user-site|python3 - |python3 -c|readFileSync.*python|_PY" /root/code_exec_server.js | head -30
echo "=== all pyinj dirs & pycache ==="
for d in /tmp/pyinj_*; do echo "$d"; ls -la "$d"; head -3 "$d/sitecustomize.py" 2>/dev/null; done
echo "=== node procs serving (how many) ==="
ps aux | grep code_exec_server | grep -v grep
echo "[DONE]"
