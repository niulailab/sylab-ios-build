#!/bin/bash
echo "=== grep for table name across host code ==="
grep -rl "sylab_scheduled_tasks" /root --include="*.py" --include="*.js" --include="*.ts" 2>/dev/null | grep -v node_modules | head -30
echo ""
echo "=== grep internal/fire callers ==="
grep -rl "internal/fire" /root --include="*.py" --include="*.js" --include="*.ts" 2>/dev/null | grep -v node_modules | head -30
echo ""
echo "=== chat-queue-service dir listing ==="
ls -la /root/chat-queue-service/
