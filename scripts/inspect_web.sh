#!/bin/bash
set +e
echo "===== /root/sylab-app git ====="
cd /root/sylab-app 2>/dev/null && { git remote -v; git rev-parse HEAD; git status -s | head; echo "-- branch --"; git branch --show-current; }
echo "===== version markers ====="
grep -E '"version"' /root/sylab-app/package.json | head -1
grep -n "MAX_EXTRACT_ATTEMPTS" /root/sylab-app/src/api/skillExtract.ts | head
echo "===== webroot sylab-ios ====="
ls -la /var/www/sylab-ios/ 2>/dev/null | head -20
echo "===== nginx root for s.symsgf ====="
nginx -T 2>/dev/null | grep -nE "s\.symsgf|sylab-ios|root .*www" | head -20
