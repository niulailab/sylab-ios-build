#!/bin/bash
set -e
CONF=/etc/nginx/sites-enabled/default
TS=$(date +%Y%m%d%H%M%S)
cp "$CONF" "$CONF.bak_header2_$TS"
python3 - "$CONF" <<'PY'
import sys,re
p=sys.argv[1]; s=open(p).read()
new='''location = /sylab-ios/sylab-1.0.26-v137.ipa {
        alias /var/www/sylab-ios/sylab-1.0.26-v137.ipa;
        types { }
        default_type application/octet-stream;
        add_header Content-Disposition 'attachment; filename="sylab-1.0.26-v137.ipa"' always;
        add_header X-Content-Type-Options nosniff always;
        add_header Cache-Control 'no-store, no-cache, must-revalidate, max-age=0' always;
        add_header Pragma no-cache always;
    }
'''
# 匹配当前已存在的（可能缺 alias 的）版本化块
pat=re.compile(r"location = /sylab-ios/sylab-1\.0\.26-v137\.ipa \{.*?\n\s*\}\n", re.S)
if not pat.search(s):
    print('block not found'); raise SystemExit(1)
s=pat.sub(new, s, count=1)
open(p,'w').write(s)
print('replaced block')
PY
nginx -t && systemctl reload nginx && echo RELOADED
echo DONE
