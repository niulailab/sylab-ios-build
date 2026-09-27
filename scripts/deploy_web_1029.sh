#!/bin/bash
set -e
# public repo, raw works without token
curl -sL "https://raw.githubusercontent.com/niulailab/sylab-ios-build/main/artifacts/sylab-web-1.0.29.tar.gz" -o /tmp/_extra
SIZE=$(stat -c%s /tmp/_extra)
echo "downloaded bytes=$SIZE"
[ "$SIZE" -gt 1000000 ] || { echo "download too small, abort"; exit 1; }
file /tmp/_extra
if [ -f /root/coze-studio/scripts/deploy_web_final.sh ]; then
  bash /root/coze-studio/scripts/deploy_web_final.sh
else
  curl -sL "https://raw.githubusercontent.com/niulailab/sylab-ios-build/main/scripts/deploy_web_final.sh" -o /tmp/deploy_web_final.sh
  bash /tmp/deploy_web_final.sh
fi
echo DONE_WEB
