#!/bin/bash
echo "### start_code_exec.sh ###"
cat /root/start_code_exec.sh
echo ""
echo "### code-exec.service ###"
cat /etc/systemd/system/code-exec.service 2>/dev/null || systemctl cat code-exec.service 2>/dev/null
echo ""
echo "### coze-server 内部进程 ###"
docker exec coze-server ps -ef 2>/dev/null | grep -vE "ps -ef" | head -20
echo "[DONE]"
