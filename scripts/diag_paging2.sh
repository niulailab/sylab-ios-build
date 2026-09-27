#!/bin/bash
# 只读诊断：内部直查 mysql。不修改任何东西。
echo "===== TIME ====="; date
MC=coze-mysql

runmysql(){
  local sql="$1"
  docker exec -e Q="$sql" "$MC" sh -lc 'mysql -uroot -p"$MYSQL_ROOT_PASSWORD" -N -e "$Q" 2>&1'
}
echo "===== databases ====="; runmysql "SHOW DATABASES;"
echo "===== tables like conversation ====="; runmysql "SHOW TABLES FROM opencoze LIKE '%conversation%';"
echo "===== top conversations by msg count ====="
runmysql "SELECT conversation_id, COUNT(*) AS c FROM opencoze.conversation_message GROUP BY conversation_id ORDER BY c DESC LIMIT 8;"
echo "===== total rows ====="; runmysql "SELECT COUNT(*) FROM opencoze.conversation_message;"
echo "===== DONE ====="
