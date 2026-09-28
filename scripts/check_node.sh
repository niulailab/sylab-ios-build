#!/bin/bash
echo "=== node procs ==="
ps aux | grep -E "code_exec_server" | grep -v grep
echo "=== last log ==="
tail -25 /root/code_exec_server.log
echo "=== ports 909x ==="
ss -ltnp 2>/dev/null | grep -E "909[0-9]"
echo "[DONE]"
