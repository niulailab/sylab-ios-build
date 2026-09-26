#!/bin/bash
F=/root/sylab-app/src/components/MarkdownRenderer.tsx
echo "===== link onPress / open url logic ====="
grep -nE "Linking|openURL|onPress|openExternally|openLink|handleLink|canOpenURL" "$F" | head -40
echo
echo "===== link color ====="
grep -nE "linkColor|colors\.link|color:.*link|#2563eb|#3b82f6|#60a5fa|#9ca3af|#999|gray|underline" "$F" | head -30
echo
echo "===== link regex & link node builders in parseInline ====="
grep -nE "\\\\\[.*\\\\\]|LINK_RE|linkRe|\\[([^|m[0-9]|href|\\\\(https?|m\[2\]|m\[1\]" "$F" | head -30