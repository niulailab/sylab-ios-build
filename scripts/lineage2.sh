#!/bin/bash
cd /root/sylab-app || exit 1
echo "===== HEAD ====="
git rev-parse --short HEAD
git log -1 --pretty='%h %ad %s' --date=format:'%m-%d %H:%M'
echo "===== working tree status (uncommitted = r6/r7 on top of HEAD) ====="
git status --short | head -30
echo "===== diff stat vs HEAD ====="
git diff --stat | tail -20
echo "===== app.json version diff vs HEAD ====="
git diff -- app.json | grep -E '^[+-].*(version|build|versionCode)' | head
echo "===== historical fix markers present in CURRENT files ====="
echo "-- v123 MVCP-after-layout (MarkdownRenderer/chat) --"
grep -rnE "layout settle|debounce|MVCP|onLayout" app/chat/\[id\].tsx | head -5
echo "-- v124 inline image ZoomableImage --"
grep -rnE "ZoomableImage|inline image|\[.*\]\(.*\.(png|jpg|jpeg)" src/components/MarkdownRenderer.tsx | head -5
echo "-- r6 renderStyledContent present --"
grep -c renderStyledContent src/components/MarkdownRenderer.tsx
echo "-- r7 absolute overlay present --"
grep -n "bottom: '100%'" app/chat/\[id\].tsx