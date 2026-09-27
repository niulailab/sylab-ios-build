#!/bin/bash
CID=$(docker ps --format '{{.Names}}'|grep -i mysql|head -1)
cat > /tmp/_q.sql <<'SQL'
SELECT TO_BASE64(prompt) FROM single_agent_draft WHERE agent_id=7669580347859795968;
SQL
cat /tmp/_q.sql | docker exec -i "$CID" sh -lc 'mysql -N -uroot -p"$MYSQL_ROOT_PASSWORD" --default-character-set=utf8mb4 opencoze 2>/dev/null' | tr -d '\n' > /tmp/_dp.b64
python3 - <<'PY'
import base64,json
raw=base64.b64decode(open('/tmp/_dp.b64').read())
d=json.loads(raw.decode())
p=d['prompt']
assert '运维与部署授权' in p
open('/tmp/_newp.txt','w').write(p)
print("ok prompt len",len(p))
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
