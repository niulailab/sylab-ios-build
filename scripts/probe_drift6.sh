#!/bin/bash
PID=349248
echo "=== process cmdline / cwd ==="
tr '\0' ' ' < /proc/$PID/cmdline; echo
ls -l /proc/$PID/cwd 2>/dev/null
ls -l /proc/$PID/exe 2>/dev/null
echo
echo "=== open files (.js) ==="
ls -l /proc/$PID/cwd/ 2>/dev/null | head
readlink /proc/$PID/cwd
CWD=$(readlink /proc/$PID/cwd)
echo "--- grep internal/fire handler in cwd js ---"
grep -rIln --include=*.js -e "internal/fire" -e "internal/status-by-uuid" "$CWD" 2>/dev/null | head
echo "[DONE]"
