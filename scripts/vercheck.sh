#!/bin/bash
echo "===== app version ====="
grep -E '"version"|"buildNumber"|"versionCode"' /root/sylab-app/app.json | head
grep -m1 '"version"' /root/sylab-app/package.json
echo "===== r6 patch in SOURCE MarkdownRenderer ====="
grep -nE 'renderStyledContent' /root/sylab-app/src/components/MarkdownRenderer.tsx | head
echo "count: $(grep -c renderStyledContent /root/sylab-app/src/components/MarkdownRenderer.tsx)"
echo "===== r7 patch in SOURCE chat page ====="
grep -nE "bottom: '100%'|position: 'absolute'" /root/sylab-app/app/chat/\[id\].tsx | head
echo "===== file mtimes ====="
stat -c '%y %n' /root/sylab-app/src/components/MarkdownRenderer.tsx /root/sylab-app/app/chat/\[id\].tsx 2>/dev/null
echo "===== web-build time vs source ====="
stat -c '%y %n' /root/sylab-app/web-build/index.html
B=$(grep -oE 'entry-[A-Za-z0-9]+\.js' /root/sylab-app/web-build/index.html | head -1)
echo "bundle=$B"
BP="/root/sylab-app/web-build/_expo/static/js/web/$B"
stat -c '%y %n' "$BP" 2>/dev/null
echo "===== r7 feature string inside shipped bundle ====="
grep -oE 'bottom:"100%"' "$BP" | head
grep -c 'renderStyledContent\|StyledContent' "$BP"
echo "===== latest IPA on disk ====="
ls -l --time-style=long-iso /var/www/sylab-ios/sylab-unsigned.ipa 2>/dev/null
