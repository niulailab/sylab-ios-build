#!/bin/bash
# 给版本化 IPA 加 attachment 下载头，防止 Safari 直接渲染二进制成乱码。改前备份。
set -e
CONF=/etc/nginx/sites-enabled/default
TS=$(date +%Y%m%d%H%M%S)
cp "$CONF" "$CONF.bak_header_$TS"
echo "backup: $CONF.bak_header_$TS"

# 找到 sylab-ios 的 location 块，在其中加入针对版本化文件的头
python3 - "$CONF" <<'PY'
import sys,re
p=sys.argv[1]
s=open(p).read()
if 'sylab-1.0.26-v137.ipa' in s:
    print('already configured'); raise SystemExit
# 在 sylab-unsigned exact location 附近插入一个 exact location
anchor='location = /sylab-ios/sylab-unsigned.ipa'
block='''location = /sylab-ios/sylab-1.0.26-v137.ipa {
        add_header Content-Disposition 'attachment; filename="sylab-1.0.26-v137.ipa"';
        add_header X-Content-Type-Options nosniff;
        add_header Cache-Control "no-store";
    }
'''
if anchor in s:
    s=s.replace(anchor, block+anchor,1)
    open(p,'w').write(s)
    print('inserted before', anchor)
else:
    print('ANCHOR NOT FOUND')
    raise SystemExit(1)
PY

nginx -t && systemctl reload nginx && echo RELOADED
echo DONE
