#!/bin/bash
Q="SHOW TABLES LIKE '%bot%';"
docker exec -e Q="$Q" coze-mysql sh -c 'mysql -uroot -p"$MYSQL_ROOT_PASSWORD" -N -e "$Q"' 2>/dev/null
