#!/bin/bash
MP=$(docker exec coze-mysql printenv MYSQL_ROOT_PASSWORD)
M(){ docker exec coze-mysql mysql -uroot -p"$MP" opencoze -e "$1" 2>/dev/null; }

echo "### 1. 该run时段消息(秒级时间戳) ###"
M "SELECT FROM_UNIXTIME(created_at,'%H:%i:%s') t, role, type, LEFT(content,75)
   FROM message WHERE conversation_id='7687609248154386432'
   AND created_at BETWEEN 1790676000 AND 1790676800 ORDER BY created_at;"

echo ""
echo "### 2. message表是否有存tool调用的列 ###"
M "SELECT column_name FROM information_schema.columns WHERE table_schema='opencoze' AND table_name='message' 
   AND (column_name LIKE '%tool%' OR column_name LIKE '%extra%' OR column_name LIKE '%meta%' OR column_name LIKE '%json%');"

echo ""
echo "### 3. 该时段assistant消息数(按type) ###"
M "SELECT type,COUNT(*) FROM message WHERE conversation_id='7687609248154386432' 
   AND created_at BETWEEN 1790676000 AND 1790676800 AND role='assistant' GROUP BY type;"

echo ""
echo "### 4. 10:23卡住的in_progress run现在状态 ###"
M "SELECT id,status,FROM_UNIXTIME(created_at/1000,'%H:%i:%s') FROM run_record WHERE id=7690866570133766144;"

echo "[DONE]"
