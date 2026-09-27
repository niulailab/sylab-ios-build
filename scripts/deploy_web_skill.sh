#!/bin/bash
# Deploy web static build (skill library) to /var/www/chat-sdk
# New build tarball is uploaded to /tmp/_extra (created by CI scp).
set -e
TS=$(date +%Y%m%d%H%M%S)
WEBROOT=/var/www/chat-sdk
PKG=/tmp/_extra

if [ ! -f "$PKG" ]; then
  echo "ERROR: $PKG missing"
  exit 1
fi

mkdir -p /var/www/chat-sdk-backup
if [ -d "$WEBROOT" ]; then
  tar czf /var/www/chat-sdk-backup/chat-sdk-pre-$TS.tar.gz -C /var/www chat-sdk
  echo "backup -> /var/www/chat-sdk-backup/chat-sdk-pre-$TS.tar.gz"
fi

STAGE=/tmp/_webstage_$TS
rm -rf "$STAGE"
mkdir -p "$STAGE"
tar xzf "$PKG" -C "$STAGE"
SRC=$(find "$STAGE" -mindepth 1 -maxdepth 1 -type d | head -1)
echo "staged source: $SRC"

find "$WEBROOT" -mindepth 1 -maxdepth 1 ! -name 'backup' -exec rm -rf {} +
cp -a "$SRC"/. "$WEBROOT"/
rm -rf "$STAGE"

echo "deployed files:"
ls -la "$WEBROOT" | head
echo "OK web deployed at $TS"
