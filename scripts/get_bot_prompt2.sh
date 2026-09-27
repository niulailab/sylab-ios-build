#!/bin/bash
echo "=== containers ==="
docker ps --format '{{.Names}}' | grep -i mysql
echo "=== tables ==="
docker exec coze-mysql sh -c 'mysql -uroot -p"$MYSQL_ROOT_PASSWORD" -N -e "SHOW TABLES LIKE \"%bot%\";"' 2>&1 | grep -v "Using a password"
