#!/bin/bash
MP=$(docker exec coze-mysql printenv MYSQL_ROOT_PASSWORD)
M(){ docker exec coze-mysql mysql -uroot -p"$MP" opencoze -N -e "$1" 2>/dev/null; }

echo "### A. message表真相 ###"
echo "--- 表名 ---"
M "SHOW TABLES LIKE '%message%';"
echo "--- 该conv消息总数(不带时间条件) ---"
M "SELECT COUNT(*) FROM message WHERE conversation_id='7687609248154386432';"
echo "--- message表总行数 ---"
M "SELECT COUNT(*) FROM message;"

echo ""
echo "### B. 目标run(log-id 7ebcc4cb)工具调用端点统计 ###"
docker logs coze-server --since 5h 2>&1 | grep "7ebcc4cb" > /tmp/rl.txt
echo "该run日志总行数: $(wc -l < /tmp/rl.txt)"
grep -oE "url=http://tool-proxy:9092[^,]*" /tmp/rl.txt | sed 's|url=http://tool-proxy:9092||' | sed 's/?.*//' | sort | uniq -c

echo ""
echo "### C. 工具OnStart序列(前40个工具名) ###"
grep '"Component":"Tool"' /tmp/rl.txt | grep -oE '"Name":"[^"]*"' | head -40

echo ""
echo "### D. 最后15次HTTP调用的body ###"
grep "invocation_http.go" /tmp/rl.txt | grep -oE "body=.*" | tail -15

echo "[DONE]"
