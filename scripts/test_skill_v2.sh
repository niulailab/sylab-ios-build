#!/bin/bash
set -e

# Get MySQL password from docker environment
MYSQL_PWD=$(docker inspect coze-mysql 2>/dev/null | python3 -c "
import json,sys
data=json.load(sys.stdin)
env = data[0]['Config']['Env']
for e in env:
    if e.startswith('MYSQL_ROOT_PASSWORD'):
        print(e.split('=',1)[1])
        break
" 2>/dev/null)
echo "MySQL pwd found: ${MYSQL_PWD:+yes}"

# Query users via docker exec
echo "=== Users ==="
docker exec coze-mysql mysql -u root -p"$MYSQL_PWD" opencoze -N -e "SELECT id, name, email FROM user LIMIT 5" 2>/dev/null

# Find session table
echo "=== Session tables ==="
docker exec coze-mysql mysql -u root -p"$MYSQL_PWD" opencoze -N -e "SHOW TABLES LIKE '%session%'" 2>/dev/null

# Check if we can create a session directly or find API token
echo "=== API token / key tables ==="
docker exec coze-mysql mysql -u root -p"$MYSQL_PWD" opencoze -N -e "SHOW TABLES LIKE '%token%'" 2>/dev/null
docker exec coze-mysql mysql -u root -p"$MYSQL_PWD" opencoze -N -e "SHOW TABLES LIKE '%key%'" 2>/dev/null
docker exec coze-mysql mysql -u root -p"$MYSQL_PWD" opencoze -N -e "SHOW TABLES LIKE '%auth%'" 2>/dev/null

# The key insight: v3/chat can work with personal access token (PAT)
# Check if there's a pat table
echo "=== PAT tables ==="
docker exec coze-mysql mysql -u root -p"$MYSQL_PWD" opencoze -N -e "SHOW TABLES LIKE '%pat%'" 2>/dev/null
docker exec coze-mysql mysql -u root -p"$MYSQL_PWD" opencoze -N -e "SHOW TABLES LIKE '%personal%'" 2>/dev/null
