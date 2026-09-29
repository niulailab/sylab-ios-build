#!/bin/bash
echo "### 个人令牌/会话token 相关表 ###"
MP=$(docker exec coze-mysql printenv MYSQL_ROOT_PASSWORD)
docker exec coze-mysql mysql -uroot -p"$MP" opencoze -e "SELECT table_name FROM information_schema.tables WHERE table_schema='opencoze' AND (table_name LIKE '%token%' OR table_name LIKE '%session%');" 2>/dev/null
echo ""
echo "### v3 chat/conversation 路由(Go) ###"
timeout 40 grep -rniE "v3/chat|/v3/chat|chat/completions|conversation.*create" /root/coze-studio/backend --include=*.go 2>/dev/null | grep -viE "_test|\.bak|api/model|biz/model" | head -12
echo ""
echo "### PAT/token 表数据探查 ###"
for t in personal_access_token personal_token user_token access_token; do
  c=$(docker exec coze-mysql mysql -uroot -p"$MP" opencoze -N -e "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='opencoze' AND table_name='$t';" 2>/dev/null)
  [ "$c" = "1" ] && echo "== $t ==" && docker exec coze-mysql mysql -uroot -p"$MP" opencoze -e "SELECT * FROM $t LIMIT 3\G" 2>/dev/null | grep -iE "id:|token|user|name|expire" | head -12
done
echo "[DONE]"
