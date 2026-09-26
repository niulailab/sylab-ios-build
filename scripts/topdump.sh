#!/bin/bash
F=/root/sylab-app/src/components/MarkdownRenderer.tsx
echo "===== top: component start, how content is preprocessed/split (1-120) ====="
sed -n '1,120p' "$F" | grep -nE "props|content|split|replace|\\\\n|trimmedContent|const lines|trim|normalize"
echo "--- exact lines 600-680 (component start region) ---"
sed -n '600,700p' "$F"