#!/bin/bash
MP=$(docker exec coze-mysql printenv MYSQL_ROOT_PASSWORD)
M(){ docker exec coze-mysql mysql -uroot -p"$MP" opencoze -e "$1" 2>/dev/null; }

echo "### 1. 该run模型每次请求的reasoning_content实际值统计 ###"
docker logs coze-server --since 6h 2>&1 | grep "7ebcc4cb" | grep -oE '"reasoning_content":"[^"]{0,30}' | sort | uniq -c | head
echo "--- 非空reasoning出现次数 ---"
docker logs coze-server --since 6h 2>&1 | grep "7ebcc4cb" | grep -oE '"reasoning_content":"[^"]' | grep -v '"reasoning_content":""' | wc -l

echo ""
echo "### 2. bot版本的模型配置 ###"
M "SELECT column_name FROM information_schema.columns WHERE table_schema='opencoze' AND table_name='single_agent_version' 
   AND (column_name LIKE '%model%' OR column_name LIKE '%reason%' OR column_name LIKE '%think%' OR column_name LIKE '%llm%');"

echo ""
echo "### 3. 该bot版本完整模型字段 ###"
M "SELECT * FROM single_agent_version WHERE version=7669597666208120832\G" 2>&1 | grep -iE "model|reason|think|llm|mode" | head -20

echo ""
echo "### 4. 后端默认模型/思考配置 ###"
grep -rniE "reasoning|thinking|enable_thinking|chat_model|default.*model" /root/coze-studio/.env* 2>/dev/null | head -10
grep -rniE "model_name|enable.*think|reasoning" /root/coze-studio/backend/conf/ 2>/dev/null | head -15

echo "[DONE]"
