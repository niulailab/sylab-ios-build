#!/bin/bash
MP=$(docker exec coze-mysql printenv MYSQL_ROOT_PASSWORD)
M(){ docker exec coze-mysql mysql -uroot -p"$MP" opencoze -e "$1" 2>/dev/null; }

echo "### 该会话最近25条消息（原始created_at + 转换）###"
M "SELECT created_at, FROM_UNIXTIME(created_at) u1, FROM_UNIXTIME(created_at/1000) u2,
   role, type, LEFT(content,50)
   FROM message WHERE conversation_id='7687609248154386432'
   ORDER BY created_at DESC LIMIT 25;"

echo "[DONE]"
