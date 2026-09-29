#!/bin/bash
MP=$(docker exec coze-mysql printenv MYSQL_ROOT_PASSWORD)
M(){ docker exec coze-mysql mysql -uroot -p"$MP" opencoze -N -e "$1" 2>/dev/null; }

echo "### 1. 找'测试开始'那条消息所在会话 ###"
M "SELECT id, conversation_id, FROM_UNIXTIME(created_at,'%H:%i:%s') FROM message 
   WHERE content LIKE '%测试开始%先提交%' ORDER BY created_at DESC LIMIT 3;"

echo ""
echo "### 2. 最近20条run_record（时间/状态/错误）###"
docker exec coze-mysql mysql -uroot -p"$MP" opencoze -e "
SELECT id, conversation_id, status, FROM_UNIXTIME(created_at,'%m-%d %H:%i:%s') t,
       LEFT(COALESCE(last_error,''),100) err
FROM run_record ORDER BY created_at DESC LIMIT 20;" 2>/dev/null

echo ""
echo "### 3. 该会话18:00-18:10全部消息（看最后停在哪）###"
M "SELECT role, LEFT(content,80), FROM_UNIXTIME(created_at,'%H:%i:%s') t
   FROM message WHERE created_at BETWEEN 1788941320 AND 1788942600
   AND conversation_id IN (SELECT conversation_id FROM (SELECT conversation_id FROM message WHERE content LIKE '%测试开始%先提交%' LIMIT 3) x)
   ORDER BY created_at;"

echo "[DONE]"
