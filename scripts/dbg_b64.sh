#!/bin/bash
CID=$(docker ps --format '{{.Names}}'|grep -i mysql|head -1)
cat > /tmp/_q.sql <<'SQL'
SELECT TO_BASE64(prompt) FROM single_agent_draft WHERE agent_id=7669580347859795968;
SQL
cat /tmp/_q.sql | docker exec -i "$CID" sh -lc 'mysql -N -uroot -p"$MYSQL_ROOT_PASSWORD" --default-character-set=utf8mb4 opencoze 2>/dev/null' > /tmp/_dp.raw
wc -c /tmp/_dp.raw
head -c 120 /tmp/_dp.raw | cat -A
echo
echo "--- filtered len ---"
python3 - <<'PY'
s=open('/tmp/_dp.raw').read()
good=''.join(c for c in s if c.isalnum() or c in '+/=')
print("good len",len(good),"mod4",len(good)%4)
print("non-good chars:",set(c for c in s if not(c.isalnum() or c in '+/=')))
PY
echo DONE
