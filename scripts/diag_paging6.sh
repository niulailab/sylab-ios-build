#!/bin/bash
echo "===== TIME ====="; date
MC=coze-mysql
runmysql(){ docker exec -e Q="$1" "$MC" sh -lc 'mysql -uroot -p"$MYSQL_ROOT_PASSWORD" -N -e "$Q" 2>/dev/null'; }

# 找 test@sylab.com 自己拥有、消息最多的会话
TUID=$(runmysql "SELECT id FROM opencoze.user WHERE email='test@sylab.com' LIMIT 1;")
echo "test user db id: $TUID"
runmysql "SELECT DISTINCT user_id FROM opencoze.conversation LIMIT 5;"
echo "--- conversations row for test (user_id col is varchar external id) ---"
runmysql "SELECT id,user_id,name FROM opencoze.conversation WHERE user_id LIKE '%test%' OR creator_id=$TUID ORDER BY id DESC LIMIT 10;"

echo
echo "===== LOGIN ====="
LOGIN=$(curl -s -m 10 -D /tmp/_hdr -X POST "http://127.0.0.1:9091/api/passport/web/email/login/" \
  -H 'Content-Type: application/json' \
  -d '{"email":"test@sylab.com","password":"123456"}')
echo "login body: $(echo "$LOGIN" | head -c 300)"
echo "--- cookies ---"; grep -i "set-cookie" /tmp/_hdr | head
SK=$(grep -i "set-cookie" /tmp/_hdr | sed -n 's/.*session_key=\([^;]*\).*/\1/p' | head -1)
echo "session_key: ${SK:0:20}..."
echo "===== DONE ====="
