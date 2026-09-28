#!/bin/bash
echo "=== scheduler-service dir (9088 node) ==="
ls -la /root/coze-studio/scheduler-service/ 2>/dev/null
echo ""
echo "--- package.json ---"
cat /root/coze-studio/scheduler-service/package.json 2>/dev/null | head -30
echo ""
echo "=== file list + sizes ==="
find /root/coze-studio/scheduler-service -maxdepth 2 -type f -not -path "*/node_modules/*" 2>/dev/null | head -30

echo ""
echo "=== automation-service dir (8910) ==="
ls -la /root/coze-studio/automation-service/ 2>/dev/null | head -20

echo ""
echo "=== Is 9088 a container or host process? ==="
ps aux | grep -E "node|349248" | grep -v grep | head -5
echo ""
# what is pid 349248
ls -l /proc/349248/cwd 2>/dev/null
cat /proc/349248/cmdline 2>/dev/null | tr '\0' ' '
echo ""
