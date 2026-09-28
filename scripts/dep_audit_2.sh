#!/bin/bash
echo "=== status-by-uuid endpoint full ==="
awk '/status-by-uuid/,0' /root/chat-queue-service/server.js | sed -n '1,80p'
