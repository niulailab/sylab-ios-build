#!/bin/bash
CID=$(docker ps --format '{{.Names}}' | grep -i mysql | head -1)
echo "container=$CID"
docker exec "$CID" sh -lc 'mysql -uroot -p"$MYSQL_ROOT_PASSWORD" opencoze -N -e "SHOW COLUMNS FROM single_agent_draft;"' 2>&1 | grep -v "Using a password"
