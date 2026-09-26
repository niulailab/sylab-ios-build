#!/bin/bash
F=/root/sylab-app/src/components/MarkdownRenderer.tsx
echo "===== parseInline head + regex defs (400-470) ====="
sed -n '400,470p' "$F"
echo
echo "===== where parseInline is called (per-line?) ====="
grep -nE "parseInline|split\('\\\\n'\)|lines|\\\\.split|for .*line" "$F" | head -30