#!/bin/bash
# 只读诊断 v2：内部直查 mysql + 直打 coze-server 分页接口。不修改任何东西。
echo "===== TIME ====="; date
MC=coze-mysql
echo "===== mysql env ====="
docker exec "$MC" sh -lc 'echo "rootpw_set=${MYSQL_ROOT_PASSWORD:+yes}"; env | grep -i mysql | sed "s/=.*/=***/"' 2>/dev/null

runmysql(){ docker exec "$MC" sh -lc "mysql -uroot -p\"$MYSQL_ROOT_PASSWORD\" -N -e \"$1\"" 2>/dev/null; }
echo "===== databases ====="; runmysql "SHOW DATABASES;"
echo "===== tables like conversation ====="; runmysql "SHOW TABLES FROM opencoze LIKE '%conversation%';"
echo "===== top conversations by msg count ====="
runmysql "SELECT conversation_id, COUNT(*) c FROM opencoze.conversation_message GROUP BY conversation_id ORDER BY c DESC LIMIT 8;"

echo
echo "===== coze-server internal port mapping ====="
docker port coze-server 2>/dev/null
docker inspect coze-server --format '{{range .NetworkSettings.Networks}}{{.IPAddress}} {{end}}' 2>/dev/null

echo "===== internal message list page1/2/3 (via docker IP) ====="
# 找一个消息最多的会话
CID=$(runmysql "SELECT conversation_id FROM opencoze.conversation_message GROUP BY conversation_id ORDER BY COUNT(*) DESC LIMIT 1;")
echo "test conversation: $CID"
if [ -n "$CID" ]; then
  # 内部登录获取 session
  SRV=$(docker inspect coze-server --format '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' 2>/dev/null | awk '{print $1}')
  echo "coze-server ip: $SRV"
fi
echo "===== DONE ====="
