#!/usr/bin/env bash
exec > /var/www/sylab-ios/ui1_0930.txt 2>&1
set +e
MP=$(docker exec coze-mysql printenv MYSQL_ROOT_PASSWORD)
Q(){ docker exec coze-mysql mysql -uroot -p"$MP" -e "$1" opencoze 2>&1; }
QN(){ docker exec coze-mysql mysql -uroot -p"$MP" -N -e "$1" opencoze 2>&1; }

echo "##### 1. section 相关表"
QN "SELECT table_name FROM information_schema.tables WHERE table_schema='opencoze' AND (table_name LIKE '%section%' OR table_name LIKE '%card%' OR table_name LIKE '%file%');"

echo
echo "##### 2. 今天带文件/md卡片的 assistant 消息"
Q "SELECT id,conversation_id,role,content_type,message_type,status,broken_position,section_id,created_at FROM message WHERE created_at>='2026-09-30 12:00:00' ORDER BY id DESC LIMIT 25;"

echo
echo "##### 3. 12:25左右该会话消息内容(阿凡达让做md)"
Q "SELECT id,conversation_id,role,content_type,status,LEFT(content,600) AS content,LEFT(ext,400) AS ext FROM message WHERE created_at>='2026-09-30 12:20:00' AND created_at<='2026-09-30 12:30:00' ORDER BY id ASC;"
