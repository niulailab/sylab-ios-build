#!/bin/bash
echo "=== config/runtime ==="
find /root/sylab-app/src/config -type f | grep -v bak
cat /root/sylab-app/src/config/runtime.* 2>/dev/null | grep -vE "^\s*//" | head -60
echo ""
echo "=== where app stores logged-in user (store/auth) ==="
ls /root/sylab-app/src/store/
grep -rnE "user_id|userId|user\.id|open_id|openId" /root/sylab-app/src/store/ 2>/dev/null | grep -v bak | head -20
echo ""
echo "=== profile.tsx: user object & menu ==="
grep -nE "user|userId|user_id|menu|菜单|navigation|router|useUser|authStore" /root/sylab-app/app/\(tabs\)/profile.tsx | head -40
