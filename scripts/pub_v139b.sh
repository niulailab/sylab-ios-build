#!/bin/bash
set -e
D=/var/www/sylab-ios
TS=$(date +%Y%m%d%H%M%S)
cp "$D/sylab-unsigned.ipa" "$D/sylab-1.0.28-v139.ipa"
chmod 644 "$D/sylab-1.0.28-v139.ipa"
cp /etc/nginx/sites-enabled/default /etc/nginx/sites-enabled/default.bak_v139name_$TS

python3 - <<'PY'
import re
f="/etc/nginx/sites-enabled/default"
s=open(f).read()
if "sylab-1.0.28-v139.ipa" in s:
    print("already present")
else:
    lines=s.split("\n")
    idx=None
    for i,l in enumerate(lines):
        if re.match(r"\s*location\s*=\s*/sylab-ios/sylab-unsigned\.ipa\s*\{", l):
            idx=i; break
    assert idx is not None, "unsigned location not found"
    ind=re.match(r"(\s*)", lines[idx]).group(1) or "    "
    block=[
      ind+'location = /sylab-ios/sylab-1.0.28-v139.ipa {',
      ind+'    alias /var/www/sylab-ios/sylab-1.0.28-v139.ipa;',
      ind+'    types { }',
      ind+'    default_type application/octet-stream;',
      ind+"    add_header Content-Disposition 'attachment; filename=\"sylab-1.0.28-v139.ipa\"' always;",
      ind+'    add_header Cache-Control "no-store" always;',
      ind+'}',
      '',
    ]
    lines[idx:idx]=block
    open(f,"w").write("\n".join(lines))
    print("block inserted before line", idx)
PY
nginx -t && systemctl reload nginx && echo reloaded
echo "=== verify ==="
curl -skI "https://s.symsgf.xyz/sylab-ios/sylab-1.0.28-v139.ipa?cb=$(date +%s)" | grep -iE "HTTP/|content-disposition|content-type|content-length"
md5sum "$D/sylab-1.0.28-v139.ipa"
echo PUB_V139_OK
