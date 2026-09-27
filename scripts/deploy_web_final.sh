#!/bin/bash
set -e
TS=$(date +%Y%m%d%H%M%S)
WEBROOT=/var/www/chat-sdk
PKG=/tmp/_extra
[ -f "$PKG" ] || { echo "ERROR: $PKG missing"; exit 1; }

# backup
mkdir -p /var/www/chat-sdk-backup
[ -d "$WEBROOT" ] && tar czf /var/www/chat-sdk-backup/chat-sdk-pre-$TS.tar.gz -C /var/www chat-sdk
echo "backup done"

STAGE=/tmp/_webstage_$TS
rm -rf "$STAGE"; mkdir -p "$STAGE"
tar xzf "$PKG" -C "$STAGE"

# preserve custom sw.js if existing live one exists
if [ -f "$WEBROOT/sw.js" ]; then
  cp "$WEBROOT/sw.js" "$STAGE/sw.js"
  echo "preserved live sw.js"
fi

# swap content, keep *.bak* and sw backups
find "$WEBROOT" -mindepth 1 -maxdepth 1 ! -name '*.bak*' -exec rm -rf {} +
cp -a "$STAGE"/. "$WEBROOT"/
rm -rf "$STAGE"
systemctl reload nginx
echo "=== deployed ==="
ls -la "$WEBROOT" | head -20
echo "=== verify new bundle marker via https ==="
B=$(grep -o '/_expo/static/js/web/entry-[a-z0-9]*\.js' "$WEBROOT/index.html" | head -1)
echo "bundle=$B"
curl -sk "https://s.symsgf.xyz$B" | grep -c "u6280" >/dev/null && echo "bundle reachable"
echo "WEB_DEPLOY_OK $TS"
