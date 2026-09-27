#!/bin/bash
docker exec coze-mysql sh -c 'mysql -uroot -p"$MYSQL_ROOT_PASSWORD" -N opencoze -e "SHOW TABLES;"' 2>/dev/null
