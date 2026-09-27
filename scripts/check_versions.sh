#!/bin/bash
CID=$(docker ps --format '{{.Names}}'|grep -i mysql|head -1)
cat > /tmp/_q.sql <<'SQL'
SELECT id, agent_id, version, create_time FROM single_agent_version WHERE agent_id=7669580347859795968 ORDER BY create_time DESC LIMIT 10;
SELECT id, agent_id, publish_id, version, status FROM single_agent_publish WHERE agent_id=7669580347859795968 ORDER BY id DESC LIMIT 10;
SQL
cat /tmp/_q.sql | docker exec -i "$CID" sh -lc 'mysql -uroot -p"$MYSQL_ROOT_PASSWORD" --default-character-set=utf8mb4 opencoze 2>&1' | grep -v "Using a password"
echo DONE
