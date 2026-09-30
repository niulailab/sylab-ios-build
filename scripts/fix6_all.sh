#!/usr/bin/env bash
exec > /var/www/sylab-ios/fix6_0930.txt 2>&1
set +e
MP=$(docker exec coze-mysql printenv MYSQL_ROOT_PASSWORD)
Q(){ docker exec coze-mysql mysql -uroot -p"$MP" -e "$1" opencoze 2>&1; }

echo "##### 复位前"
Q "SELECT id,status,last_status,consecutive_failures,next_run_at FROM sylab_scheduled_tasks WHERE id IN(11,12);"

Q "UPDATE sylab_scheduled_tasks SET last_status=NULL, consecutive_failures=0 WHERE id IN(11,12) AND status='active';"
echo "affected rows above"
echo
echo "##### 复位后"
Q "SELECT id,title,status,last_status,consecutive_failures,run_count,next_run_at FROM sylab_scheduled_tasks WHERE id IN(11,12);"
