#!/bin/bash
set -euo pipefail
RAW="https://raw.githubusercontent.com/niulailab/sylab-ios-build/main"
APP=/root/sylab-app

echo "=== download sources ==="
curl -sSL "$RAW/app_src_scheduled/scheduledTasks.ts" -o "$APP/src/api/scheduledTasks.ts"
curl -sSL "$RAW/app_src_scheduled/scheduled-tasks.tsx" -o "$APP/app/scheduled-tasks.tsx"
echo "downloaded:"
wc -l "$APP/src/api/scheduledTasks.ts" "$APP/app/scheduled-tasks.tsx"

echo ""
echo "=== apply profile patch ==="
curl -sSL "$RAW/scripts/app_profile_patch_v140.sh" -o /tmp/profile_patch.sh
bash /tmp/profile_patch.sh

echo ""
echo "=== verify files placed ==="
ls -la "$APP/src/api/scheduledTasks.ts" "$APP/app/scheduled-tasks.tsx"
grep -n "定时任务" "$APP/app/(tabs)/profile.tsx"
echo "[DONE deploy]"
