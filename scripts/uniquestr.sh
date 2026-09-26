#!/bin/bash
F=/root/sylab-app/src/components/MarkdownRenderer.tsx
echo "===== candidate unique recent strings in current source ====="
grep -noE "状态|状态卡|预览|真正的普通网页|App 内闭环|绝不跳外部浏览器|仅真正|文件链接：显示文件卡片" "$F" | head
J=/tmp/ipachk2/ex/Payload/sylab.app/main.jsbundle
echo
echo "===== check each in bundle ====="
for s in "仅真正的普通网页链接才允许外部浏览器" "绝不跳外部浏览器" "文件链接：显示文件卡片" "真正的普通网页" "App 内闭环"; do
  c=$(grep -aF -o "$s" "$J" | wc -l)
  echo "[$c] $s"
done
echo
echo "===== chinese strings surviving near link color in bundle ====="
grep -aoE "浏览器|网页|预览|链接" "$J" | sort | uniq -c