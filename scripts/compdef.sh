#!/bin/bash
F=/root/sylab-app/src/components/MarkdownRenderer.tsx
grep -nE "export (const|function) MarkdownRenderer|MarkdownRenderer =|const lines|trimmedContent|\.split\('\\\\n'\)|\.split\(\"\\\\n\"\)|props\)" "$F"
echo "=== component region (find export) ==="
LN=$(grep -nE "export (const|function) MarkdownRenderer" "$F"|head -1|cut -d: -f1)
echo "export at $LN"
[ -n "$LN" ] && sed -n "${LN},$((LN+70))p" "$F"