#!/bin/bash
# 只读诊断：容器 uptime + 后端分页接口。不修改任何东西。
echo "===== HOST TIME ====="; date
echo "===== CONTAINERS (uptime) ====="
docker ps --format '{{.Names}}\t{{.Image}}\t{{.Status}}' 2>/dev/null | sort
echo
echo "===== nginx listen / proxies ====="
grep -RnE "listen |proxy_pass|location " /etc/nginx/sites-enabled/ 2>/dev/null | head -60
echo
echo "===== internal message list (via coze-server) ====="
# 尝试从 mysql 找一个有较多消息的会话
if command -v docker >/dev/null 2>&1; then
  MYSQLC=$(docker ps --format '{{.Names}}' | grep -iE 'mysql' | head -1)
  echo "mysql container: $MYSQLC"
  if [ -n "$MYSQLC" ]; then
    docker exec "$MYSQLC" sh -lc 'mysql -uroot -p"$MYSQL_ROOT_PASSWORD" -N -e "
SELECT conversation_id, COUNT(*) c FROM opencoze.conversation_message GROUP BY conversation_id ORDER BY c DESC LIMIT 5;" 2>/dev/null' \
      || docker exec "$MYSQLC" sh -lc 'mysql -uroot -N -e "SHOW DATABASES;" 2>/dev/null'
  fi
fi
echo "===== DONE ====="
