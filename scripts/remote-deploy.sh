#!/usr/bin/env bash
set -e
D=/var/www/sylab-ios
TS=$(date +%Y%m%d_%H%M%S)
cp "$D/sylab-unsigned.ipa" "$D/sylab-unsigned.ipa.bak_before_native_$TS"
cp /tmp/sylab-native-new.ipa "$D/sylab-unsigned.ipa"
chmod 644 "$D/sylab-unsigned.ipa"
cp /tmp/sylab-native-new.ipa "$D/sylab-v127.zip"
chmod 644 "$D/sylab-v127.zip"
md5sum "$D/sylab-unsigned.ipa"
systemctl reload nginx
echo DEPLOY_DONE
