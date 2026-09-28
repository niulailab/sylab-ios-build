#!/bin/bash
grep -n "async function executePython" /root/code_exec_server.js
L=$(grep -n "async function executePython" /root/code_exec_server.js | head -1 | cut -d: -f1)
sed -n "${L},$((L+6))p" /root/code_exec_server.js | cat -A | head -8
echo "[DONE]"
