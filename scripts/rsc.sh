#!/bin/bash
F=/root/sylab-app/src/components/MarkdownRenderer.tsx
echo "===== renderStyledContent definition (230-320) ====="
sed -n '230,320p' "$F"
echo
echo "===== exact call sites with context ====="
grep -nE "renderStyledContent" "$F"