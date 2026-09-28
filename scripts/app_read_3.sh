#!/bin/bash
echo "=== auth store interface: what's returned by useAuthStore ==="
grep -nE "sessionId|SESSION_KEY|Storage.getItem|return \{|interface AuthState|user:|session" /root/sylab-app/src/store/auth.ts | head -30
echo ""
echo "=== how session stored in Storage (key name) ==="
grep -nE "SESSION_KEY\s*=|Storage.setItem\(SESSION_KEY" /root/sylab-app/src/store/auth.ts
echo ""
echo "=== storage util getItem ==="
grep -rnE "export.*Storage|getItem" /root/sylab-app/src/utils/storage.* 2>/dev/null | head
ls /root/sylab-app/src/utils/ | grep -iE "storage"
