#!/bin/bash
set -e
D=/var/www/sylab-ios
TS=$(date +%Y%m%d%H%M%S)
cp "$D/sylab-unsigned.ipa" "$D/sylab-1.0.28-v139.ipa"
chmod 644 "$D/sylab-1.0.28-v139.ipa"
cp /etc/nginx/sites-enabled/default /etc/nginx/sites-enabled/default.bak_v139name_$TS

python3 - <<'PY'
p="/etc/nginx/sites-enabled"
import glob
f="/etc/nginx/sites-enabled/default"
s=open(f).read()
block='''    location = /sylab-ios/sylab-1.0.28-v139.ipa {
        alias /var/www/sylab-ios/sylab-1.0.28-v139.ipa;
        types { }
        default_type application/octet-stream;
        add_header Content-Disposition 'attachment; filename="sylab-1.0.28-v139.ipa"' always;
        add_header Cache-Control "no-store" always;
    }

'''
if "sylab-1.0.28-v139.ipa" not in s:
    anchor="    location = /sylab-ios/sylab-unsigned.ipa {"
    assert anchor in s
    s=s.replace(anchor, block+anchor, 1)
    open(f,"w").write(s)
    print("nginx block added")
else:
    print("already present")
PY
nginx -t && systemctl reload nginx && echo reloaded
echo "=== verify versioned ==="
curl -skI "https://s.symsgf.xyz/sylab-ios/sylab-1.0.28-v139.ipa?cb=$(date +%s)" | grep -iE "HTTP|content-disposition|content-type|content-length"
md5sum "$D/sylab-1.0.28-v139.ipa"
echo PUB_V139_OK
