#!/bin/bash

# Login first to get session
curl -s -c /tmp/ck.txt -X POST http://localhost:9091/api/passport/web/email/login/ \
  -H 'Content-Type: application/json' \
  -d '{"email":"test@sylab.com","password":"123456"}' > /dev/null
SK=$(grep session_key /tmp/ck.txt | awk '{print $NF}')

# Create PAT via internal API
echo "=== Create PAT ==="
curl -s -b "session_key=$SK" -X POST \
  "http://localhost:9091/api/permission_api/pat/create_personal_access_token_and_permission" \
  -H 'Content-Type: application/json' \
  -d '{"name":"skill-test","description":"test","duration":30}'
echo ""

# Also try the v3 endpoint with session cookie directly (not Bearer)
echo "=== Try v3/chat with cookie auth only ==="
# First create conversation via internal API (not OpenAPI)
curl -s -b "session_key=$SK" -X POST \
  "http://localhost:9091/api/conversation/create" \
  -H 'Content-Type: application/json' \
  -d '{"bot_id":"7669580347859795968"}'
echo ""

# Check what the web frontend actually uses - look at web chat
echo "=== Check web dist for auth patterns ==="
grep -o 'session_key=[^"]*' /var/www/chat-sdk/assets/*.js 2>/dev/null | head -3
grep -o 'Authorization[^,]*Bearer[^,]*' /var/www/chat-sdk/assets/*.js 2>/dev/null | head -5
