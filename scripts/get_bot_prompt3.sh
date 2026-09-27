#!/bin/bash
echo "=== tables like bot ==="
docker exec coze-mysql sh -c 'mysql -uroot -p"$MYSQL_ROOT_PASSWORD" -N opencoze -e "SHOW TABLES LIKE \"%bot%\";"' 2>&1 | grep -v "Using a password"
