#!/bin/bash
MP=$(docker exec coze-mysql printenv MYSQL_ROOT_PASSWORD)
M(){ docker exec coze-mysql mysql -uroot -p"$MP" opencoze -e "$1" 2>/dev/null; }

echo "### 1. bot/plugin 关系相关表 ###"
M "SELECT table_name FROM information_schema.tables WHERE table_schema='opencoze' 
   AND (table_name LIKE '%plugin%' OR table_name LIKE '%bot%' OR table_name LIKE '%agent%');"

echo ""
echo "### 2. tool表里的视频/命令工具 ###"
M "SELECT id, LEFT(name,40) name, type FROM tool WHERE name LIKE '%video%' OR name LIKE '%command%' OR name LIKE '%run%' ORDER BY id;"

echo ""
echo "### 3. placeholder循环期间模型实际有没有收到错误信号 ###"
docker logs coze-server --since 5h 2>&1 | grep "7ebcc4cb" | grep -iE "OnResult.*run_command|tool.*success|result.*placeholder" | grep -oE '"(code|status|success)"[:=]*[0-9a-z]*' | sort | uniq -c | head

echo "[DONE]"
