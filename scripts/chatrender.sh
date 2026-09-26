#!/bin/bash
F=/root/sylab-app/app/chat/\[id\].tsx
echo "===== imports of markdown / render components in chat screen ====="
grep -nE "import|Markdown|Render|Bubble|MessageBody|MessageContent|RichText" "$F" | grep -iE "markdown|render|bubble|richtext|message" | head -30
echo
echo "===== where assistant content is rendered (JSX) ====="
grep -nE "<Markdown|<.*Render|<.*Bubble|content|renderContent|MessageText" "$F" | head -30