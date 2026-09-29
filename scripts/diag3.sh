#!/bin/bash
MP=$(docker exec coze-mysql printenv MYROOT_PASSWORD 2>/dev/null); [ -z "$MP" ] && MP=$(docker exec coze-mysql printenv MYSQL_ROOT_PASSWORD)
M(){ docker exec coze-mysql mysql -uroot -p"$MP" opencoze -e "$1" 2>/dev/null; }

echo "### 1. run_record created_at 列类型 ###"
M "SELECT column_name,data_type FROM information_schema.columns WHERE table_schema='opencoze' AND table_name='run_record' AND column_name IN('created_at','updated_at');"

echo ""
echo "### 2. 该会话16条run时间分布 ###"
M "SELECT id,status,created_at,updated_at FROM run_record WHERE conversation_id='7687609248154386432' ORDER BY created_at;"

echo ""
echo "### 3. 该会话18:00-18:12消息流（角色+内容前60字）###"
M "SELECT FROM_UNIXTIME(created_at,'%H:%i:%s') t, role, LEFT(content,60) FROM message 
   WHERE conversation_id='7687609248154386432' AND created_at BETWEEN 1788940800 AND 1788942200 ORDER BY created_at;"

echo ""
echo "### 4. 当前生效 MaxStep 配置 ###"
docker exec coze-server env 2>/dev/null | grep -iE "max.?step" 
grep -riE "maxstep|max_step|MaxStep" /root/coze-studio/.env* /root/coze-studio/docker-compose*.yml 2>/dev/null | head -5
grep -rn "200" /root/coze-studio/backend/conf/*.yaml 2>/dev/null | grep -i step | head -5

echo "[DONE]"
