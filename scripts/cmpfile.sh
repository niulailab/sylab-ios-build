#!/bin/bash
echo "===== server copy markers ====="
S=/root/sylab-app/src/components/MarkdownRenderer.tsx
wc -l "$S"; md5sum "$S"
grep -cE "renderStyledContent" "$S"
echo
echo "===== build repo (local checkout) markers ====="
for B in /root/sylab-ios-build /root/build /root/sylab-ios-build-repo; do
  [ -d "$B" ] && echo "found dir $B"
done
ls -d /root/*build* /root/*sylab* 2>/dev/null
echo
echo "===== how deploy workflow gets source ====="
grep -nE "git clone|checkout|repository|sylab-app|rsync|scp|/root/sylab" /root/sylab-app/.github/workflows/*.yml 2>/dev/null | head
ls /root/sylab-app/.github/workflows/ 2>/dev/null