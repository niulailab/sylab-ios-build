#!/bin/bash
echo "### 1. 停止 systemd 重启循环 ###"
systemctl stop code-exec.service
sleep 3
echo "### 2. 杀掉孤儿旧进程 ###"
for p in $(ss -ltnp 2>/dev/null | grep ':9097' | grep -oE 'pid=[0-9]+' | cut -d= -f2 | sort -u); do
  echo "kill pid=$p"; kill "$p" 2>/dev/null
done
# 兜底按名杀
pkill -f "node /root/code_exec_server.js" 2>/dev/null
sleep 4
if ss -ltn 2>/dev/null | grep -q ':9097'; then
  echo "端口仍占用，强杀"; for p in $(ss -ltnp | grep ':9097' | grep -oE 'pid=[0-9]+'|cut -d= -f2); do kill -9 "$p"; done
  sleep 3
fi
ss -ltn 2>/dev/null | grep ':9097' && echo "!! 端口还在" || echo "9097 已释放"
echo "### 3. systemd 拉起新代码 ###"
systemctl start code-exec.service
sleep 7
systemctl is-active code-exec.service
echo "### 新进程 ###"
ps -ef | grep code_exec_server | grep -v grep
ss -ltnp 2>/dev/null | grep 9097
echo "[DONE]"
