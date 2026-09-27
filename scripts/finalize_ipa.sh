#!/bin/bash
SRC=/var/www/sylab-ios/sylab-unsigned.ipa
DIR=/var/www/sylab-ios
cp -n "$SRC" "$DIR/sylab-1.0.29-v140.ipa" 2>/dev/null || echo "release copy exists"
ls -lah "$DIR" | grep -iE 'ipa'
echo "=== md5 compare ==="
md5sum "$SRC" "$DIR/sylab-1.0.29-v140.ipa"
echo "=== https download header ==="
curl -skI --max-time 30 "https://s.symsgf.xyz/sylab-ios/sylab-unsigned.ipa?cb=$(date +%s)" | grep -iE 'HTTP/|content-disposition|content-length|content-type'
echo "=== web version marker (build29 / 1.0.29) ==="
grep -o '1\.0\.29\|build29' /var/www/chat-sdk/index.html | head -3 || true
ls /var/www/chat-sdk/_expo/static/js/web/
echo DONE
