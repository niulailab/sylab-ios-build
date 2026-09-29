#!/bin/bash
echo "### 行数 ###"; wc -l /root/coze-studio/ADMIN_NOTES.md
echo "### 章节标题 ###"; grep -nE "^#{1,3} " /root/coze-studio/ADMIN_NOTES.md | head -40
echo "[DONE]"
