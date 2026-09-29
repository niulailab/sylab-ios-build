#!/bin/bash
MP=$(docker exec coze-mysql printenv MYSQL_ROOT_PASSWORD)
M(){ docker exec coze-mysql mysql -uroot -p"$MP" opencoze -e "$1" 2>/dev/null; }

echo "### 1. 正确时间窗内该会话消息 ###"
M "SELECT FROM_UNIXTIME(created_at/1000,'%H:%i:%s') t, role, type, LEFT(content,70)
   FROM message WHERE conversation_id='7687609248154386432'
   AND created_at BETWEEN 1790676000000 AND 1790676800000 ORDER BY created_at;"

echo ""
echo "### 2. tool/call 相关表 ###"
M "SELECT table_name FROM information_schema.tables WHERE table_schema='opencoze' AND (table_name LIKE '%tool%' OR table_name LIKE '%call%');"

echo ""
echo "### 3. 该run消息条数按角色 ###"
M "SELECT role,type,COUNT(*) FROM message WHERE conversation_id='7687609248154386432'
   AND created_at BETWEEN 1790676000000 AND 1790676800000 GROUP BY role,type;"

echo ""
echo "### 4. MaxStep 源码常量 ###"
grep -rnE "[Mm]axStep|max_step|MaxStep" /root/coze-studio/backend 2>/dev/null | grep -iE "= *[0-9]+|200|30" | head -10

echo "[DONE]"
