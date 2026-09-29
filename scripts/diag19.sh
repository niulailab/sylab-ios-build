#!/bin/bash
PID=2367368
echo "### 1. 9097 node进程的工作目录/启动文件 ###"
readlink /proc/$PID/cwd
tr '\0' ' ' < /proc/$PID/cmdline; echo ""

echo ""
echo "### 2. 该目录下找模型映射(100015) ###"
CWD=$(readlink /proc/$PID/cwd)
timeout 40 grep -rniE "100015" "$CWD" --include=*.js --include=*.json --include=*.ts --include=*.yaml --include=*.env 2>/dev/null | grep -viE "node_modules/.*\.map" | head -10

echo ""
echo "### 3. 找thinking配置 ###"
timeout 40 grep -rniE "enable_thinking|thinking" "$CWD" --include=*.js --include=*.json 2>/dev/null | grep -viE "node_modules/[^/]+/README|\.map:" | head -10

echo ""
echo "### 4. 该服务是否docker容器 ###"
cat /proc/$PID/cgroup 2>/dev/null | grep -oE "docker[-/][0-9a-f]{12}" | head -1

echo "[DONE]"
