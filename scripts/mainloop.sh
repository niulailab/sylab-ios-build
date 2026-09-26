#!/bin/bash
F=/root/sylab-app/src/components/MarkdownRenderer.tsx
echo "===== main component + block loop (1110-1327) ====="
sed -n '1110,1327p' "$F"