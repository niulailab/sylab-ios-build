#!/bin/bash
cd /root/sylab-app
LOG=/tmp/sylab_web_build.log
: > "$LOG"
nohup bash -c '
  set -x
  cd /root/sylab-app
  echo "=== install missing web deps ==="
  npm install --no-audit --no-fund react-dom@18.2.0 @expo/metro-runtime
  echo "=== export web ==="
  npx expo export --platform web --output-dir /root/sylab-app/web-build
  echo "WEB_EXPORT_RC=$?"
' >> "$LOG" 2>&1 &
echo "started pid $!, log=$LOG"
sleep 5
tail -5 "$LOG"
