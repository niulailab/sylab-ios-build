#!/usr/bin/env bash
exec > /var/www/sylab-ios/fix4_0930.txt 2>&1
set +e
BIN=/app/opencoze
echo "##### 二进制路径确认"
docker exec coze-server ls -la /app/opencoze
echo
echo "##### 调度相关字符串 (选任务/状态判断)"
docker exec coze-server sh -c "command -v strings >/dev/null 2>&1 && strings /app/opencoze | grep -Ei 'sylab_scheduled_tasks|sylab_schedule_runs|next_run_at|consecutive_failures|last_status|running' | grep -Ei 'select|update|status|running|next_run|sched' | head -40" || echo "strings not available"
