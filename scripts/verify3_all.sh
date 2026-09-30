#!/usr/bin/env bash
exec > /var/www/sylab-ios/verify3_0930.txt 2>&1
set +e
MP=$(docker exec coze-mysql printenv MYSQL_ROOT_PASSWORD)
Q(){ docker exec coze-mysql mysql -uroot -p"$MP" -e "$1" opencoze 2>&1; }
echo "##### 1. sylab_scheduled_tasks 列"
Q "SHOW COLUMNS FROM sylab_scheduled_tasks;" | awk '{print $1}'
echo
echo "##### 2. 现存任务全字段"
Q "SELECT * FROM sylab_scheduled_tasks\G"
echo
echo "##### 3. sylab_schedule_runs 今日"
Q "SELECT * FROM sylab_schedule_runs WHERE created_at>='2026-09-30 00:00:00' ORDER BY id DESC\G"
echo
echo "##### 4. coze-server 是否已有 extra_hosts"
docker inspect coze-server --format '{{json .HostConfig.ExtraHosts}}'
echo
echo "##### 5. coze-server /etc/hosts 现有 tool-proxy"
docker exec coze-server cat /etc/hosts | grep -i tool || echo "none"
