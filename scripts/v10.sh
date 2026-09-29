#!/bin/bash
MP=$(docker exec coze-mysql printenv MYSQL_ROOT_PASSWORD)
C(){ docker exec coze-mysql mysql -uroot -p"$MP" opencoze -e "$1" 2>/dev/null; }
Q(){ docker exec coze-mysql mysql -uroot -p"$MP" opencoze -N -e "$1" 2>/dev/null; }

for t in tool tool_version tool_draft; do
  echo "===== $t 列 ====="
  C "SELECT column_name FROM information_schema.columns WHERE table_schema='opencoze' AND table_name='$t' ORDER BY ordinal_position;" | tr '\n' ' '; echo ""
done

echo ""
echo "===== tool 表样本(前3行全列) ====="
C "SELECT * FROM tool LIMIT 3\G" 2>&1 | head -45
echo "[DONE]"
