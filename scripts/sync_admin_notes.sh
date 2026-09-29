#!/bin/bash
# 把仓库根的 ADMIN_NOTES.md 同步到服务器现场路径
cp "$(dirname "$0")/ADMIN_NOTES.md" /root/coze-studio/ADMIN_NOTES.md 2>/dev/null \
  || cp /root/coze-studio-build/ADMIN_NOTES.md /root/coze-studio/ADMIN_NOTES.md 2>/dev/null \
  || cp ./ADMIN_NOTES.md /root/coze-studio/ADMIN_NOTES.md

echo "=== 服务器现场手册确认 ==="
ls -la /root/coze-studio/ADMIN_NOTES.md
echo "字数: $(wc -l < /root/coze-studio/ADMIN_NOTES.md) 行"
head -12 /root/coze-studio/ADMIN_NOTES.md
echo "[DONE]"
