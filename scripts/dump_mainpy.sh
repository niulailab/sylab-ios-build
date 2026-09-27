#!/usr/bin/env bash
set +e
F=/root/coze-studio/docker/memory-service-custom/main.py
echo "=====FILEB64_START====="
base64 -w0 "$F"
echo
echo "=====FILEB64_END====="
echo "=====SCHEMA====="
python3 - <<'PY'
import sqlite3
db="/data/coze-studio-data/memory-service/memory.db"
c=sqlite3.connect(db)
for r in c.execute("SELECT sql FROM sqlite_master WHERE name='memories'"):
    print(r[0])
print("---- distinct layer/category ----")
try:
    for r in c.execute("SELECT DISTINCT layer FROM memories"): print("layer:",r[0])
    for r in c.execute("SELECT DISTINCT category FROM memories"): print("cat:",r[0])
except Exception as e: print("err",e)
PY
echo "DUMP_DONE"
