#!/bin/bash
MP=$(docker exec coze-mysql printenv MYSQL_ROOT_PASSWORD)
Q(){ docker exec coze-mysql mysql -uroot -p"$MP" opencoze -e "$1" 2>/dev/null; }

for t in model_entity model_instance model_meta; do
  echo "### $t 结构 ###"
  Q "SELECT column_name FROM information_schema.columns WHERE table_schema='opencoze' AND table_name='$t' ORDER BY ordinal_position;" | tr '\n' ' '
  echo ""; echo "--- $t 行数 ---"; Q "SELECT COUNT(*) FROM $t;"
  echo ""
done
echo "### model_entity 全部（id/name/连接信息前80字）###"
Q "SELECT * FROM model_entity LIMIT 20\G" 2>&1 | grep -iE "id:|name|model|conn|url|provider|type" | head -40
echo "[DONE]"
