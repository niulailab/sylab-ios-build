#!/bin/bash
set -e
cd /tmp
rm -rf ipachk && mkdir ipachk && cd ipachk
# 用线上对外的 ipa（本机 nginx 路径）
IPA=$(ls -la /var/www/html/sylab-unsigned.ipa 2>/dev/null || find / -maxdepth 4 -name 'sylab-unsigned.ipa' 2>/dev/null | head -1)
echo "ipa file: $IPA"
ls -la "$IPA"
unzip -q "$IPA" -D ex
BUNDLE=$(find ex -name '*.bundle' -type d | head -1)
echo "bundle dir: $BUNDLE"
ls -la "$BUNDLE" | head
JS=$(find "$BUNDLE" -maxdepth 2 -name '*.js' -o -maxdepth 2 -name '*.bundle' 2>/dev/null | head)
echo "js files: $JS"
# r6 特征字符串（注释或独有逻辑文本），minify后注释可能没了，改用 link 处理里独有的 openExternally + 颜色
for J in $JS; do
  echo "===== $J size $(stat -c%s "$J") ====="
  echo "-- FIX link-in-bold comment (r6) --"
  grep -c "FIX link-in-bold" "$J" 2>/dev/null || echo 0
  echo "-- setMdPreviewUrl occurrences --"
  grep -o "setMdPreviewUrl" "$J" 2>/dev/null | wc -l
  echo "-- r7 bottom 100% state float marker --"
  grep -c "100%" "$J" 2>/dev/null || echo 0
done