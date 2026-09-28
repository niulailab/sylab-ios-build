#!/bin/bash
echo "=== does app login store same session_key into user row? check login flow shape ==="
echo "--- user.session_key present for all key users ---"
docker exec coze-mysql mysql -uroot -pd3G8JG273iE8C4irRWJX opencoze -e \
 "select id,name,length(session_key) sk_len, deleted_at is null alive from user where id in (7666848996043784192,17857736066221234,7668887535984050176);" 2>/dev/null
echo ""
echo "=== how coze-server itself validates session (find middleware source) ==="
grep -rnE "session_key" /root/coze-studio/backend/ 2>/dev/null | grep -iE "where|select|query|user|match|=" | grep -v "_test" | head -15
echo ""
echo "=== how app login persists (auth.ts login) ==="
sed -n '55,130p' /root/sylab-app/src/store/auth.ts
