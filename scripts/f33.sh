#!/bin/bash
echo "===== ADMIN_NOTES 行数 + 末尾变更日志结构 ====="
wc -l /root/coze-studio/ADMIN_NOTES.md
grep -nE "变更日志|^## |^# " /root/coze-studio/ADMIN_NOTES.md | tail -15
echo "----- 末尾20行 -----"
tail -20 /root/coze-studio/ADMIN_NOTES.md
echo "[DONE]"
