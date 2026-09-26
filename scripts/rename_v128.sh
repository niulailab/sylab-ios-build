#!/bin/bash
set +e
F=/etc/nginx/sites-enabled/default
TS=$(date +%Y%m%d_%H%M%S)
cp -a "$F" "/etc/nginx/sites-enabled/default.bak_v128_$TS"
echo "backup=default.bak_v128_$TS"
echo "before count: $(grep -c 'filename="sylab-v127.ipa"' $F)"
python3 - "$F" <<'PY'
import sys
p=sys.argv[1]
s=open(p).read()
s=s.replace('filename="sylab-v127.ipa"','filename="sylab-v128.ipa"')
open(p,'w').write(s)
print("replaced")
PY
echo "after v128 count: $(grep -c 'filename="sylab-v128.ipa"' $F)"
echo "remaining v127 ipa: $(grep -c 'filename="sylab-v127.ipa"' $F)"
nginx -t 2>&1 | tail -2
if nginx -t 2>/dev/null; then systemctl reload nginx; echo RELOAD_OK; fi
echo "===== public header ====="
curl -s -m 20 -D - "https://s.symsgf.xyz/sylab-ios/sylab-unsigned.ipa?cb=$(date +%s)" -o /tmp/v.ipa | grep -iE "^HTTP|content-length|content-disposition"
echo "downloaded size=$(wc -c </tmp/v.ipa)"
cd /tmp&&rm -rf vv&&mkdir vv&&cd vv&&unzip -q /tmp/v.ipa
python3 - "./Payload/sylab.app/Info.plist" <<'PY'
import sys,plistlib
d=plistlib.load(open(sys.argv[1],'rb'))
print("SHORT",d.get('CFBundleShortVersionString'),"BUILD",d.get('CFBundleVersion'))
PY