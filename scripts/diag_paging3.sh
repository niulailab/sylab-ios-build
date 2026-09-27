#!/bin/bash
echo "===== TIME ====="; date
MC=coze-mysql
runmysql(){ docker exec -e Q="$1" "$MC" sh -lc 'mysql -uroot -p"$MYSQL_ROOT_PASSWORD" -N -e "$Q" 2>/dev/null'; }
echo "===== tables like %message% ====="; runmysql "SHOW TABLES FROM opencoze LIKE '%message%';"
echo "===== tables like %chat% ====="; runmysql "SHOW TABLES FROM opencoze LIKE '%chat%';"
echo "===== conversation table cols ====="; runmysql "SHOW COLUMNS FROM opencoze.conversation;"
echo "===== DONE ====="
