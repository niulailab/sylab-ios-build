#!/bin/bash
cd /tmp/ipachk2
echo "===== all files in .app ====="
find ex/Payload/sylab.app -maxdepth 1 -type f -exec ls -la {} \; | awk '{print $5, $9}' | sort -n | tail -25
echo
J=$(find ex/Payload/sylab.app -maxdepth 1 -name '*.jsbundle' -o -maxdepth 1 -name 'main.js*' | head -1)
echo "JSBUNDLE=$J"
if [ -n "$J" ]; then
 echo "size=$(stat -c%s "$J")"
 echo -n "FIX link-in-bold: "; grep -o "FIX link-in-bold" "$J" | wc -l
 echo -n "setMdPreviewUrl: "; grep -o "setMdPreviewUrl" "$J" | wc -l
 echo -n "openExternally: "; grep -o "openExternally" "$J" | wc -l
 echo -n "Linking openURL: "; grep -o "openURL" "$J" | wc -l
fi