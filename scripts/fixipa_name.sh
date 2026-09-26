#!/bin/bash
echo "===== locate sylab-ios location blocks ====="
nginx -T 2>/dev/null | grep -nE "sylab-ios|sylab-unsigned|Content-Disposition|add_header.*attachment|alias |root " | grep -iE "sylab-ios|unsigned|disposition|attachment" 
echo
echo "===== files containing the disposition ====="
grep -rln "sylab-v127.ipa\|sylab-unsigned.ipa" /etc/nginx/ 2>/dev/null
