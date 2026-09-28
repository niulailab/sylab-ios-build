#!/bin/bash
docker exec coze-mysql mysql -uroot -pd3G8JG273iE8C4irRWJX opencoze -e "select id,email,phone,name,status from user limit 10\G" 2>/dev/null
