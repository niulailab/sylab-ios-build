#!/bin/bash
ls -la /var/www/chat-sdk/ 2>/dev/null | head -20
echo "---"
find /var/www/chat-sdk/ -name "*.js" -type f 2>/dev/null | head -10
echo "---"
ls -la /var/www/sylab-ios/ 2>/dev/null | head -10
