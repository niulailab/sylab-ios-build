#!/bin/bash
# 复制一份带版本号的 IPA，强制 attachment 下载。不动原文件。
set -e
SRC=/var/www/sylab-ios/sylab-unsigned.ipa
DST=/var/www/sylab-ios/sylab-1.0.26-v137.ipa
cp -f "$SRC" "$DST"
chmod 644 "$DST"
ls -la --time-style=full-iso /var/www/sylab-ios/sylab-1.0.26-v137.ipa
md5sum "$DST" "$SRC"
echo DONE
