#!/bin/bash
echo "=== node proc cwd/cmd ==="
ls -l /proc/771162/cwd
tr '\0' ' ' < /proc/771162/cmdline; echo
echo "=== open .js files ==="
ls -l /proc/771162/fd 2>/dev/null | grep -oE "/[^ ]+\.js" | sort -u | head
echo "[DONE]"
