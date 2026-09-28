#!/bin/bash
echo "=== ipa file ==="
ls -la /var/www/sylab-ios/
echo "=== any plist ==="
find /var/www/sylab-ios/ -name "*.plist" 2>/dev/null
echo "=== nginx serving sylab-ios ==="
grep -rn "sylab-ios" /etc/nginx/sites-enabled/ /etc/nginx/conf.d/ 2>/dev/null | grep -v ".bak" | head
echo "=== guess URLs HEAD ==="
for u in \
 "https://direct.symsgf.xyz:8099/ipa/sylab-unsigned.ipa" \
 "https://s.symsgf.xyz/ipa/sylab-unsigned.ipa" ; do
 echo "-- $u"
 curl -sk -o /dev/null -w "%{http_code} %{size_download}\n" --resolve 2>/dev/null "$u" || true
done
