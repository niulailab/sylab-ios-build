#!/bin/bash

# Check how tool-proxy works - it proxies to zhipu
echo "=== tool-proxy port ==="
ss -tlnp | grep 9092
echo ""

# Check what tools the bot has - query from DB
MYSQL_PWD=$(docker inspect coze-mysql | python3 -c "
import json,sys
for e in json.load(sys.stdin)[0]['Config']['Env']:
    if e.startswith('MYSQL_ROOT_PASSWORD'): print(e.split('=',1)[1]); break
")

echo "=== Bot tools for skill extract bot ==="
docker exec coze-mysql mysql -u root -p"$MYSQL_PWD" opencoze -e "
SELECT id, bot_id, name, type FROM tool WHERE bot_id='7669580347859795968' LIMIT 20
" 2>/dev/null

echo ""
echo "=== Try direct GLM call via tool-proxy ==="
# The tool-proxy at 9092 proxies /bigmodel/v1/ to zhipu
# We need a zhipu API key - check env
ZP_KEY=$(docker inspect tool-proxy 2>/dev/null | python3 -c "
import json,sys
for e in json.load(sys.stdin)[0]['Config']['Env']:
    if 'ZHIPU' in e.upper() or 'GLM' in e.upper() or 'API_KEY' in e.upper():
        print(e)
" 2>/dev/null)
echo "Env keys: $ZP_KEY"

# Check proxy server code for how it authenticates upstream
grep -n 'api_key\|API_KEY\|Authorization\|Bearer\|token' /root/coze-studio/tool-proxy/server.py 2>/dev/null | head -20
