#!/bin/bash
docker exec coze-mysql mysql -uroot -pd3G8JG273iE8C4irRWJX opencoze -N -e "desc user;" 2>/dev/null | awk '{print $1}'
echo "--- rows ---"
docker exec coze-mysql mysql -uroot -pd3G8JG273iE8C4irRWJX opencoze -e "select * from user limit 8\G" 2>/dev/null | grep -iE "^[[:space:]]*(id|email|phone|name|status|nickname|user_name):"
