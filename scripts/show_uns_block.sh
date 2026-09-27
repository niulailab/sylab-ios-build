grep -n "sylab-unsigned.ipa\|sylab-1.0.26-v137" /etc/nginx/sites-enabled/default
echo "=== context ==="
grep -n -A8 "location = /sylab-ios/sylab-unsigned.ipa" /etc/nginx/sites-enabled/default
