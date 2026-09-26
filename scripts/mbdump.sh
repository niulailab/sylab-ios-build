#!/bin/bash
F=/root/sylab-app/src/components/MessageBubble.tsx
ls -la "$F"; echo "lines=$(wc -l < "$F")"
echo "===== imports ====="
grep -nE "^import|Markdown|Linking|openExternally|Render" "$F" | head -20
echo
echo "===== link / onPress / markdown usage ====="
grep -nE "onPress|Linking|openURL|openExternally|Markdown|link|selectable|Text" "$F" | head -40