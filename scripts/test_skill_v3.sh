#!/bin/bash
set -e

MYSQL_PWD=$(docker inspect coze-mysql 2>/dev/null | python3 -c "
import json,sys
data=json.load(sys.stdin)
env = data[0]['Config']['Env']
for e in env:
    if e.startswith('MYSQL_ROOT_PASSWORD'):
        print(e.split('=',1)[1])
        break
" 2>/dev/null)

# Check api_key table structure and contents
echo "=== api_key structure ==="
docker exec coze-mysql mysql -u root -p"$MYSQL_PWD" opencoze -e "DESCRIBE api_key" 2>/dev/null

echo ""
echo "=== api_key entries ==="
docker exec coze-mysql mysql -u root -p"$MYSQL_PWD" opencoze -e "SELECT id, user_id, name, LEFT(\`key\`,20) as key_prefix, status FROM api_key LIMIT 10" 2>/dev/null
