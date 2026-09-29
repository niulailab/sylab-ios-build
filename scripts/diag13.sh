#!/bin/bash
MP=$(docker exec coze-mysql printenv MYSQL_ROOT_PASSWORD)
M(){ docker exec coze-mysql mysql -uroot -p"$MP" opencoze -e "$1" 2>/dev/null; }

echo "### 1. 数据库里 model 100015 ###"
M "SHOW TABLES LIKE '%model%';"
M "SELECT table_name FROM information_schema.tables WHERE table_schema='opencoze' AND table_name LIKE '%model%';"

echo ""
echo "### 2. 配置文件里 100015 ###"
grep -rn "100015" /root/coze-studio/backend/conf/ 2>/dev/null | head -10

echo ""
echo "### 3. 模型定义文件列表 ###"
ls /root/coze-studio/backend/conf/model/ 2>/dev/null
find /root/coze-studio/backend/conf/model -name "*.yaml" 2>/dev/null | head -30

echo ""
echo "### 4. model_style=2 含义(源码) ###"
grep -rniE "model_style|ModelStyle" /root/coze-studio/backend --include=*.go 2>/dev/null | grep -iE "= *2|think|reason|//" | head -10

echo "[DONE]"
