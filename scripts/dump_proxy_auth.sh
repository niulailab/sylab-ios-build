#!/bin/bash
# Find zhipu proxy function and how it adds auth upstream
grep -n "zhipu_proxy\|bigmodel\|ZHIPU_KEY\|upstream\|open.bigmodel" /root/coze-studio/tool-proxy/server.py | head -20
echo "==="
# Dump the zhipu proxy function
python3 <<'PY'
import re
with open('/root/coze-studio/tool-proxy/server.py') as f:
    lines = f.readlines()

# Find zhipu_proxy function
start = None
for i, l in enumerate(lines):
    if 'def zhipu_proxy' in l or ('zhipu' in l.lower() and 'bigmodel' in l.lower() and ('async def' in l or 'def ' in l)):
        start = i
        break
    if 'bigmodel' in l and ('@app' in l):
        # route decorator, next function
        start = i

if start:
    # Print 80 lines from start
    for i in range(start, min(start+80, len(lines))):
        print(f"{i+1}: {lines[i]}", end='')
PY
