#!/bin/bash

echo "### 1. 定位18:00前后的 run（run_record表）###"
MP=$(docker exec coze-mysql printenv MYSQL_ROOT_PASSWORD)
docker exec coze-mysql mysql -uroot -p"$MP" opencoze -e "
SELECT id, conversation_id, status, 
       LEFT(COALESCE(error_message,''),150) as err,
       created_at, updated_at,
       LEFT(COALESCE(statistics,''),120) as stats
FROM run_record 
WHERE created_at BETWEEN UNIX_TIMESTAMP('2026-09-29 17:55:00') AND UNIX_TIMESTAMP('2026-09-29 18:10:00')
ORDER BY created_at DESC\G" 2>/dev/null

echo ""
echo "### 2. run_record表的error相关字段名 ###"
docker exec coze-mysql mysql -uroot -p"$MP" opencoze -N -e "
SELECT column_name FROM information_schema.columns 
WHERE table_schema='opencoze' AND table_name='run_record'
AND (column_name LIKE '%error%' OR column_name LIKE '%status%' OR column_name LIKE '%reason%' OR column_name LIKE '%end%');" 2>/dev/null

echo ""
echo "### 3. coze-server 17:59-18:05 关键日志（error/cancel/timeout/panic）###"
docker logs coze-server --since 3h 2>&1 | grep -iE "error|cancel|timeout|panic|fatal|abort|中断|失败|EOF|context" | grep -viE "error_message.*string|grpc|health|no error|err:<nil>" | tail -40

echo "[DONE]"
