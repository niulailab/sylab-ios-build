#!/bin/bash
cd /root/coze-studio/tool-proxy
echo "=== tool-proxy 所有备份文件 ==="
ls -lht server.py.bak* 2>/dev/null | head -20
echo
echo "=== 当前 server.py 大小/修改时间 ==="
ls -l server.py
echo
echo "=== 当前 _watch_final 函数关键片段 ==="
grep -n "range(180)\|二次补偿\|等待执行结果超时\|for _i in range" server.py | head
echo
echo "=== chat-queue-service 备份 ==="
ls -lht /root/chat-queue-service/server.js.bak* 2>/dev/null | head -20
echo
echo "=== 之前其他相关补丁 ==="
ls -lht /root/coze-studio/tool-proxy/patch_*.sh /root/coze-studio/tool-proxy/*fix*.sh 2>/dev/null | head
echo
echo "=== pm2 进程状态 ==="
pm2 list 2>/dev/null
echo
echo "=== tool-proxy 进程启动方式 ==="
PID=$(pgrep -f "python.*server\.py" | head -1 || true)
echo "PID=$PID"
[ -n "$PID" ] && tr '\0' ' ' < /proc/$PID/cmdline && echo
[ -n "$PID" ] && echo "PPID=$(awk '{print $4}' /proc/$PID/stat)" && tr '\0' ' ' < /proc/$(awk '{print $4}' /proc/$PID/stat)/cmdline 2>/dev/null && echo
echo "[DONE]"
