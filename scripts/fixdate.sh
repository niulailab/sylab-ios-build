#!/bin/bash
python3 - <<'PY'
p="/root/coze-studio/ADMIN_NOTES.md"
s=open(p,encoding="utf-8").read()
s=s.replace("- `date +%Y-%m-%d`：**修复LLM空转","- 2026-09-29：**修复LLM空转",1)
open(p,"w",encoding="utf-8").write(s)
PY
grep -n "修复LLM空转" /root/coze-studio/ADMIN_NOTES.md | cut -c1-30
echo "[DONE]"
