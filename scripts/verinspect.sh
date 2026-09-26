#!/bin/bash
echo "===== app.json version fields ====="
grep -nE '"version"|"buildNumber"|"ios"|"versionCode"' /root/sylab-app/app.json | head
echo
echo "===== package.json version ====="
grep -nE '"version"' /root/sylab-app/package.json | head -1
echo
echo "===== deploy-native-via-runner.yml exists? ====="
ls -la /root/sylab-app/.github/workflows/
echo
echo "===== check-version-bump script logic ====="
cat /root/sylab-app/scripts/check-version-bump.sh 2>/dev/null | head -40