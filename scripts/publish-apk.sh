#!/bin/bash
set -e
APK=$(ls -t /root/sylab-app/android/app/build/outputs/apk/release/*.apk 2>/dev/null | head -1)
echo "APK=$APK"; ls -la "$APK"
DST=/var/www/sylab-ios/sylab-v127-android.apk
cp "$APK" "$DST"
md5sum "$DST"
echo "URL=https://s.symsgf.xyz/sylab-ios/sylab-v127-android.apk"
