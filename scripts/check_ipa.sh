#!/bin/bash
echo "=== find v140 ipa ==="
find /var/www /root /data -maxdepth 4 -name '*v140*' 2>/dev/null
echo "=== ipa dir listing ==="
ls -lah /var/www/chat-sdk/*.ipa* 2>/dev/null
ls -lah /var/www/*.ipa* 2>/dev/null
# common download dir
for d in /var/www/downloads /var/www/files /var/www/ipafiles /root/downloads; do
 [ -d "$d" ] && echo "-- $d" && ls -lah "$d" | grep -iE 'ipa|v140'
done
echo DONE
