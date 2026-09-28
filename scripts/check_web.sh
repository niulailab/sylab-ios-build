#!/bin/bash
ls -la /var/www/chat-sdk/entry-*.js 2>/dev/null | head -3
echo "---"
grep -l "skill" /var/www/chat-sdk/entry-*.js 2>/dev/null | head -1 | xargs -I{} basename {}
echo "---"
cat /var/www/chat-sdk/version.json 2>/dev/null || echo "no version.json"
