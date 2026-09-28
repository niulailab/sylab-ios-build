#!/bin/bash

# Login with correct endpoint
echo "=== LOGIN ==="
RESP=$(curl -s -c /tmp/ck.txt -X POST http://localhost:9091/api/passport/web/email/login/ \
  -H 'Content-Type: application/json' \
  -d '{"email":"test@sylab.com","password":"123456"}')
echo "$RESP" | head -c 200
echo ""
SESSION_KEY=$(grep session_key /tmp/ck.txt | awk '{print $NF}')
echo "Session: ${SESSION_KEY:0:20}..."

# Get user id
USER_ID=$(echo "$RESP" | python3 -c "import json,sys;d=json.load(sys.stdin);print(d.get('user_id',d.get('data',{}).get('user_id','')))" 2>/dev/null)
echo "UserID: $USER_ID"

# Need a conversation_id - create or find one
# First check bot list
echo ""
echo "=== Bot check ==="
curl -s -b "session_key=$SESSION_KEY" "http://localhost:9091/api/bot/list" 2>/dev/null | python3 -c "
import json,sys
try:
    d=json.load(sys.stdin)
    bots = d.get('data',{}).get('bots',d.get('bots',[]))
    for b in bots[:5]:
        print(b.get('id'),b.get('name'))
except: pass
" 2>/dev/null

