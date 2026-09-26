#!/bin/bash
set -e
MYIP="82.156.201.157"
echo "===== fail2ban status (before) ====="
fail2ban-client status sshd 2>/dev/null | grep -i banned || true

echo "===== unban $MYIP ====="
fail2ban-client set sshd unbanip "$MYIP" 2>&1 || echo "unban: not currently listed"

echo "===== persist ignoreip whitelist ====="
JL=/etc/fail2ban/jail.local
cp "$JL" "${JL}.bak_$(date +%s)" 2>/dev/null || true
touch "$JL"
if grep -q "^[[:space:]]*ignoreip" "$JL"; then
  if ! grep "^[[:space:]]*ignoreip" "$JL" | grep -q "$MYIP"; then
    sed -i "s|^\([[:space:]]*ignoreip[[:space:]]*=.*\)|\1 $MYIP|" "$JL"
  fi
else
  printf '\n[sshd]\nignoreip = 127.0.0.1/8 ::1 %s\n' "$MYIP" >> "$JL"
fi
echo "--- jail.local ignoreip lines ---"
grep -n "ignoreip" "$JL" || true
fail2ban-client -t && fail2ban-client reload sshd
echo "===== fail2ban status (after) ====="
fail2ban-client status sshd 2>/dev/null | grep -i banned || true

echo "===== DB table check ====="
CID="7687609248154386432"
docker ps --format '{{.Names}}' | grep -qi mysql && C="docker exec i mysql" || C="mysql"
docker exec $(docker ps --format '{{.Names}}' | grep -i mysql | head -1) mysql -ucoze -p'VK4DxMi0giMQAE5Xpyqo' -h127.0.0.1 opencoze -N -e "SELECT id, role, LENGTH(content), (content LIKE '%|%') AS has_pipe, (content REGEXP '\\\\|[[:space:]]*-{3,}') AS has_sep FROM message WHERE conversation_id='$CID' ORDER BY id;" 2>&1 | grep -v "Using a password" || true
