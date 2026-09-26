#!/bin/bash
IPA=/var/www/sylab-ios/sylab-unsigned.ipa
cd /tmp
rm -rf ipachk2 && mkdir ipachk2 && cd ipachk2
unzip -q "$IPA" -d ex
BUNDLE=$(find ex -name '*.bundle' -type d | head -1)
echo "bundle dir: $BUNDLE"
find "$BUNDLE" -maxdepth 2 -type f | head
J=$(find "$BUNDLE" -maxdepth 2 -name '*.js' | head -1)
[ -z "$J" ] && J=$(find "$BUNDLE" -maxdepth 2 -type f | grep -iE 'index|bundle|main' | head -1)
echo "===== inspect $J size=$(stat -c%s "$J") ====="
echo "-- r6 comment 'FIX link-in-bold':"; grep -o "FIX link-in-bold" "$J" | wc -l
echo "-- md preview 'setMdPreviewUrl':"; grep -o "setMdPreviewUrl" "$J" | wc -l
echo "-- openExternally:"; grep -o "openExternally" "$J" | wc -l
echo "-- v128 url marker play/:"; grep -o "100%" "$J" | wc -l
echo "-- version string 1.0.15:"; grep -o "1\.0\.1[0-9]" "$J" | sort -u | head