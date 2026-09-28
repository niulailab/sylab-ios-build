#!/bin/bash
echo "=== scheduled_tasks columns ==="
docker exec coze-mysql mysql -uroot -pd3G8JG273iE8C4irRWJX opencoze -e "DESC sylab_scheduled_tasks;" 2>&1 | grep -v "Using a password"
