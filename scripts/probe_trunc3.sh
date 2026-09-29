#!/bin/bash
echo "=== 1) network_error 完整上下文 ==="
docker logs tool-proxy --since "2026-09-29T09:30:00" 2>&1 | grep -B2 -A8 "network_error\|NetworkError\|read timeout\|ReadTimeout\|ConnectTimeout\|RemoteProtocolError\|RemoteDisconnected" | head -80
echo
echo "=== 2) chat-queue 服务在哪个端口，是否活着 ==="
ss -ltnp 2>/dev/null | grep -E ":9088|:9095|:9091"
echo
echo "=== 3) chat-queue pm2 进程 ==="
pm2 list 2>/dev/null | grep -iE "chat|queue|sylab"
echo
echo "=== 4) 是否有 chat-queue 进程重启记录 ==="
pm2 logs --nostream --lines 200 2>/dev/null | grep -iE "EADDRINUSE|restart|chat-queue|chat_queue|exit" | tail -20
echo
echo "=== 5) 找到 chat-queue 的真实 pm2 名称 ==="
ls /root/.pm2/logs/ 2>/dev/null | grep -iE "chat|queue"
echo "[DONE]"
