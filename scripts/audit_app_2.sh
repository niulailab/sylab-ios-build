#!/bin/bash
echo "=== tabs full listing ==="
ls -la /root/sylab-app/app/\(tabs\)/ | grep -vE "\.bak"
echo ""
echo "=== _layout.tsx (tabs) ==="
cat "/root/sylab-app/app/(tabs)/_layout.tsx" 2>/dev/null
echo ""
echo "=== src/api/automation.ts ==="
cat /root/sylab-app/src/api/automation.ts
echo ""
echo "=== src/api/client.ts ==="
cat /root/sylab-app/src/api/client.ts
