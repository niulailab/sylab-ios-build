#!/bin/bash
echo "===== TIME ====="; date
MC=coze-mysql
runmysql(){ docker exec -e Q="$1" "$MC" sh -lc 'mysql -uroot -p"$MYSQL_ROOT_PASSWORD" -N -e "$Q" 2>/dev/null'; }
echo "===== message columns ====="; runmysql "SHOW COLUMNS FROM opencoze.message;"
echo "===== total messages ====="; runmysql "SELECT COUNT(*) FROM opencoze.message;"
echo "===== top conversations ====="; runmysql "SELECT conversation_id, COUNT(*) c FROM opencoze.message GROUP BY conversation_id ORDER BY c DESC LIMIT 10;"
echo "===== DONE ====="
