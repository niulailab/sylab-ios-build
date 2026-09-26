#!/bin/bash
F=/root/sylab-app/src/components/MarkdownRenderer.tsx
echo "===== renderInlineForParagraph + renderInline (975-1110) ====="
sed -n '975,1110p' "$F"