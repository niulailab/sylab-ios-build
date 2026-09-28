#!/bin/bash
echo "=== python invocation ==="
grep -nE "python3|spawn|execFile|PYTHON|runPython|language === 'python'|=== .python.|sitecustomize|PYTHONPATH" /root/code_exec_server.js | head -40
echo "[DONE]"
