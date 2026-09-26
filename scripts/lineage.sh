#!/bin/bash
cd /root/sylab-app || { echo "no app dir"; exit 1; }
echo "===== is git repo ====="
git rev-parse --is-inside-work-tree 2>&1
git branch -a 2>&1 | head
echo "===== last 40 commits ====="
git log --date=format:'%m-%d %H:%M' --pretty='%h %ad %s' -40 2>&1
echo
echo "===== history touching the two patched files ====="
git log --date=format:'%m-%d %H:%M' --pretty='%h %ad %s' -15 -- src/components/MarkdownRenderer.tsx 2>&1
echo "---"
git log --date=format:'%m-%d %H:%M' --pretty='%h %ad %s' -15 -- 'app/chat/[id].tsx' 2>&1
