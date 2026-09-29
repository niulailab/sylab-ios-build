#!/bin/bash
echo "=== message table columns ==="
docker exec coze-mysql mysql -uroot -pd3G8JG273iE8C4irRWJX opencoze -N -e "SHOW COLUMNS FROM message;" 2>/dev/null | awk '{print $1}'
echo
echo "=== schedule_runs for task12 & task11 ==="
docker exec coze-mysql mysql -uroot -pd3G8JG273iE8C4irRWJX opencoze --default-character-set=utf8mb4 -e "SELECT task_uuid,fired_at,result_status,LEFT(detail,200) detail FROM sylab_schedule_runs WHERE task_uuid IN ('b888e0e2-441e-4eac-898b-02884c26e95c','cbf88122-e0fb-4d98-afc9-9341ccd5c14d') ORDER BY fired_at DESC \G" 2>/dev/null
echo "[DONE]"
