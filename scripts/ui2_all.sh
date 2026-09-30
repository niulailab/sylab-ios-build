#!/usr/bin/env bash
exec > /var/www/sylab-ios/ui2_0930.txt 2>&1
set +e
MP=$(docker exec coze-mysql printenv MYSQL_ROOT_PASSWORD)
Q(){ docker exec coze-mysql mysql -uroot -p"$MP" -e "$1" opencoze 2>&1; }

echo "########## A. answer 消息完整内容 ##########"
Q "SELECT id,message_type,content_type,status,broken_position,content,display_content,model_content,ext,meta_info FROM message WHERE id=7691180047872294912\G"

echo "########## B. 最后一个 tool_response(生成md的返回) ##########"
Q "SELECT id,message_type,LEFT(content,1500) AS content,LEFT(ext,600) AS ext FROM message WHERE id=7691180019741097984\G"

echo "########## C. files 表最新记录 ##########"
Q "SHOW COLUMNS FROM files;" | awk '{print $1}'
Q "SELECT * FROM files ORDER BY id DESC LIMIT 3\G"
