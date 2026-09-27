#!/bin/bash
CID=coze-mysql
docker exec "$CID" sh -lc 'mysql -uroot -p"$MYSQL_ROOT_PASSWORD" opencoze -N -e "SELECT prompt FROM single_agent_draft WHERE agent_id=7669580347859795968;"' 2>&1 | grep -v "Using a password"
