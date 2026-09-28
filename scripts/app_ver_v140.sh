#!/bin/bash
cd /root/sylab-app
echo "=== package.json version/buildNumber ==="
grep -E '"version"|buildNumber' package.json app.json app.config.* 2>/dev/null
echo "=== ios build scripts ==="
ls /root/sylab-app/scripts/ 2>/dev/null | head
echo "=== find buildNumber in files ==="
grep -rn "buildNumber\|MARKETING_VERSION\|CURRENT_PROJECT_VERSION" app.json app.config.js app.config.ts package.json 2>/dev/null | head
