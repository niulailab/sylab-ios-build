#!/usr/bin/env bash
set +e
MP=$(docker exec coze-mysql printenv MYSQL_ROOT_PASSWORD)
Q(){ docker exec coze-mysql mysql -uroot -p"$MP" -N -e "$1" opencoze 2>&1; }
echo "##### A. scheduled_task 现存任务"
Q "SELECT id,title,schedule_type,next_run_time,last_run_time,run_count,status FROM scheduled_task WHERE status!='deleted';"
echo
echo "##### B. scheduled_task 列结构"
Q "SHOW COLUMNS FROM scheduled_task;" | awk '{print $1}'
echo
echo "##### C. 今天 scheduled_task_run"
Q "SELECT id,task_id,status,started_at,finished_at,LEFT(error_message,300) FROM scheduled_task_run WHERE started_at>='2026-09-30 00:00:00' ORDER BY id;"
echo
echo "##### D. 今天 07:00-11:30 新建 conversation"
Q "SELECT id,title,created_at,updated_at FROM conversation WHERE created_at>='2026-09-30 07:00:00' AND created_at<='2026-09-30 11:30:00' ORDER BY created_at;"
echo
echo "##### E. 今天 08:00-10:30 全部 message"
Q "SELECT id,conversation_id,role,status,LEFT(content,80),created_at FROM message WHERE created_at>='2026-09-30 08:00:00' AND created_at<='2026-09-30 10:30:00' ORDER BY created_at;"
echo
echo "##### F. message 列结构"
Q "SHOW COLUMNS FROM message;" | awk '{print $1}'
echo
echo "##### G. scheduler 容器与今日日志"
docker ps -a --filter name=scheduler --format '{{.Names}} {{.Status}} {{.Image}}'
docker logs --since 2026-09-30T00:00:00 sylab-scheduler-service 2>&1 | tail -120
echo
echo "##### H. coze-server 08:20-09:00 异常日志"
docker logs --since 2026-09-30T08:20:00 --until 2026-09-30T09:00:00 coze-server 2>&1 | grep -iE 'error|panic|timeout|abort|cancel|stream|step|finish|EOF|reset' | tail -60
echo
echo "##### I. coze-server 10:10-10:25"
docker logs --since 2026-09-30T10:10:00 --until 2026-09-30T10:25:00 coze-server 2>&1 | grep -iE 'error|panic|timeout|finish|step|stream' | tail -30
echo
echo "##### J. 容器状态"
docker ps --format '{{.Names}}\t{{.Status}}'
echo "[DIAG_DONE]"
