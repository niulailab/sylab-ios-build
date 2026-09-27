#!/bin/bash
echo "===== TIME ====="; date
echo "===== /var/www/sylab-ios listing ====="
ls -la --time-style=full-iso /var/www/sylab-ios/ 2>&1 | head -40
echo "===== md5 of each ipa ====="
find /var/www/sylab-ios -maxdepth 1 -name "*.ipa" -exec md5sum {} \;
echo "===== active nginx sylab-ios block ====="
grep -nE "sylab-ios|sylab-unsigned|Content-Disposition|manifest|root |alias " /etc/nginx/sites-enabled/default | head -40
echo "===== DONE ====="
