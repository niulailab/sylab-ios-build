#!/bin/bash
echo "### node 进程与启动命令 ###"
ps -ef | grep -E "code_exec_server" | grep -v grep
echo ""
echo "### 是否有 systemd / pm2 / 守护脚本 ###"
systemctl list-units --type=service 2>/dev/null | grep -iE "code.exec|exec.server|node" | head
command -v pm2 >/dev/null && pm2 list 2>/dev/null | head
ls -la /etc/systemd/system/ 2>/dev/null | grep -iE "code|exec|node" | head
grep -rls "code_exec_server" /root/*.sh /etc/systemd/system/ 2>/dev/null | head
echo ""
echo "### 相关容器名 ###"
docker ps --format '{{.Names}}\t{{.Status}}\t{{.Ports}}' | grep -iE "tool-proxy|backend|server|api"
echo "[DONE]"
