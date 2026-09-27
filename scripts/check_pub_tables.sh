#!/bin/bash
CID=coze-mysql
Q(){ docker exec "$CID" sh -lc "mysql -uroot -p\"\$MYSQL_ROOT_PASSWORD\" --default-character-set=utf8mb4 opencoze -N --raw -e \"$1\"" 2>&1 | grep -v "Using a password"; }
echo "=== single_agent_publish cols ==="
Q 'SHOW COLUMNS FROM single_agent_publish;'
echo "=== publish rows ==="
Q 'SELECT * FROM single_agent_publish WHERE agent_id=7669580347859795968;' | head -c 3000
echo
echo "=== single_agent_version cols ==="
Q 'SHOW COLUMNS FROM single_agent_version;'
echo "=== versions ==="
Q 'SELECT id, version, status, created_at FROM single_agent_version WHERE agent_id=7669580347859795968 ORDER BY id DESC LIMIT 10;'
echo DONE
