#!/bin/bash
set -euo pipefail
cd /root/coze-studio/tool-proxy

# 1) 找 tool-proxy 进程管理方式
echo "=== supervisor / systemd / pm2 ==="
which supervisorctl pm2 2>/dev/null
supervisorctl status 2>/dev/null | head -20 || true
pm2 list 2>/dev/null | head -20 || true
ps -ef | grep -E "python.*server\.py|tool-proxy" | grep -v grep

# 2) 找到 pid，看启动命令
PID=$(pgrep -f "python.*server\.py" | head -1 || true)
echo "PID=$PID"
if [ -n "$PID" ]; then
  tr '\0' ' ' < /proc/$PID/cmdline; echo
  # 找父进程
  PPID=$(awk '{print $4}' /proc/$PID/stat)
  echo "PPID=$PPID"
  tr '\0' ' ' < /proc/$PPID/cmdline 2>/dev/null; echo
fi
