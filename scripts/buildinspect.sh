#!/bin/bash
echo "===== latest native build scripts ====="
ls -lat /root/build_native_v19*.sh /root/build_ios_v1*.sh 2>/dev/null | head
echo
echo "===== how the iOS deploy workflow builds (native via runner) ====="
ls /root/sylab-app/.github/workflows/ 2>/dev/null
echo "--- search repo workflows that compile jsbundle/expo export ---"
for w in /root/sylab-app/.github/workflows/*.yml; do
 echo "### $w"
 grep -nE "expo export|export:embed|bundle|react-native bundle|metro|workflow_dispatch|name:" "$w" 2>/dev/null | head
done