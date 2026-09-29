#!/bin/bash
echo "### systemctl status ###"
systemctl status code-exec.service --no-pager -l 2>&1 | head -20
echo ""
echo "### 最近journal ###"
journalctl -u code-exec.service --no-pager -n 20 2>&1 | tail -22
echo ""
echo "### 当前9097进程 ###"
ps -ef | grep code_exec_server | grep -v grep
ss -ltnp 2>/dev/null | grep 9097
echo "[DONE]"
