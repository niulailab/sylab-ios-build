#!/bin/bash
set -uo pipefail
cd /root/sylab-app
echo "=== tsconfig exists? ==="
ls tsconfig.json 2>/dev/null && echo yes || echo no
echo "=== tsc check (filter new files) ==="
npx tsc --noEmit --skipLibCheck 2>/tmp/tsc_full.log
RC=$?
echo "tsc exit=$RC"
echo "--- total errors ---"
grep -c "error TS" /tmp/tsc_full.log || true
echo "--- our files ---"
grep -E "scheduledTasks|scheduled-tasks|profile.tsx" /tmp/tsc_full.log || echo "NO ERRORS in our 3 files"
echo "[DONE]"
