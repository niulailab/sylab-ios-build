#!/bin/bash
CID=$(docker ps --format '{{.Names}}'|grep -i mysql|head -1)
mkdir -p /root/backups
BK=/root/backups/sylab_version_before_clause_$(date +%Y%m%d_%H%M%S).sql
docker exec "$CID" sh -lc 'mysqldump -uroot -p"$MYSQL_ROOT_PASSWORD" --default-character-set=utf8mb4 opencoze single_agent_version single_agent_publish single_agent_draft 2>/dev/null' > "$BK"
echo "backup $BK $(wc -c < $BK)"
# dump draft prompt JSON
cat > /tmp/_q.sql <<'SQL'
SELECT prompt FROM single_agent_draft WHERE agent_id=7669580347859795968;
SQL
cat /tmp/_q.sql | docker exec -i "$CID" sh -lc 'mysql -N -uroot -p"$MYSQL_ROOT_PASSWORD" --default-character-set=utf8mb4 opencoze 2>/dev/null' > /tmp/_draftprompt.json
python3 - <<'PY'
import json
s=open('/tmp/_draftprompt.json').read().strip()
d=json.loads(s)
p=d['prompt']
assert '运维与部署授权' in p, "draft clause missing!"
open('/tmp/_newp.txt','w').write(p)
print("draft prompt len",len(p))
PY
HEX=$(python3 -c "print(open('/tmp/_newp.txt').read().encode().hex())")
cat > /tmp/_upd.sql <<SQL
UPDATE single_agent_version
SET prompt=JSON_REPLACE(prompt,'\$.prompt',CONVERT(UNHEX('$HEX') USING utf8mb4))
WHERE agent_id=7669580347859795968
  AND LOCATE('运维与部署授权', JSON_UNQUOTE(JSON_EXTRACT(prompt,'\$.prompt')))=0;
SELECT id, LOCATE('运维与部署授权', JSON_UNQUOTE(JSON_EXTRACT(prompt,'\$.prompt'))) AS loc
FROM single_agent_version WHERE agent_id=7669580347859795968 ORDER BY id DESC LIMIT 4;
SQL
cat /tmp/_upd.sql | docker exec -i "$CID" sh -lc 'mysql -uroot -p"$MYSQL_ROOT_PASSWORD" --default-character-set=utf8mb4 opencoze 2>&1' | grep -v "Using a password"
echo DONE
