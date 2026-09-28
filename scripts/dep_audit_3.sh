#!/bin/bash
echo "=== all status assignments ==="
grep -nE "status['\"]?\s*[:=]\s*['\"](pending|running|succeeded|success|failed|error|canceled|completed|done)" /root/chat-queue-service/server.js | head -40
echo ""
echo "=== hset chat:task status writes ==="
grep -nE "hset\(|status:" /root/chat-queue-service/server.js | grep -iE "succeed|fail|running|pending|complete|error" | head -30
