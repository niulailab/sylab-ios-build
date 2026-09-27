#!/bin/bash
CID=coze-mysql
Q(){ docker exec "$CID" sh -lc "mysql -uroot -p\"\$MYSQL_ROOT_PASSWORD\" --default-character-set=utf8mb4 opencoze -N --raw -e \"$1\"" 2>&1 | grep -v "Using a password"; }
echo "PUBINFO_B64_BEGIN"
Q 'SELECT publish_info FROM single_agent_publish WHERE id=7669580737682604032;' | base64 -w0
echo; echo "PUBINFO_B64_END"
echo "VERSIONS_B64_BEGIN"
Q 'SELECT id, version, created_at FROM single_agent_version WHERE agent_id=7669580347859795968 ORDER BY id DESC LIMIT 8;' | base64 -w0
echo; echo "VERSIONS_B64_END"
echo DONE
