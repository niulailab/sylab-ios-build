#!/bin/bash
# 找含该链接的原始消息文本
CID=$(docker ps --format '{{.Names}}' | grep -iE 'mysql' | head -1)
echo "container=$CID"
docker exec "$CID" sh -c 'mysql -uroot -p"$MYSQL_ROOT_PASSWORD" -N -e "SELECT table_schema FROM information_schema.tables WHERE table_name=\"message\";" 2>/dev/null' | head
DB=$(docker exec "$CID" sh -c 'mysql -uroot -p"$MYSQL_ROOT_PASSWORD" -N -e "SELECT table_schema FROM information_schema.tables WHERE table_name=\"message\" LIMIT 1;" 2>/dev/null')
echo "db=$DB"
docker exec "$CID" sh -c "mysql -uroot -p\"\$MYSQL_ROOT_PASSWORD\" -N -e \"SELECT id, role, LEFT(content,600) FROM \\\`$DB\\\`.message WHERE content LIKE '%muilh1pclynn%' ORDER BY id DESC LIMIT 3;\" 2>/dev/null"
echo "----- columns -----"
docker exec "$CID" sh -c "mysql -uroot -p\"\$MYSQL_ROOT_PASSWORD\" -N -e \"SHOW COLUMNS FROM \\\`$DB\\\`.message;\" 2>/dev/null" | head -30