#!/bin/bash
echo "===== current blocks ====="
grep -n "sylab" /etc/nginx/sites-enabled/default
echo "===== full context around both locations ====="
awk '/location = \/sylab-ios\/sylab-1.0.26/{f=1} f{print} f&&/^    }/{c++; if(c>=2) exit}' /etc/nginx/sites-enabled/default
echo "===== unsigned location block ====="
awk '/location = \/sylab-ios\/sylab-unsigned.ipa/{f=1} f{print} f&&/^    }/{exit}' /etc/nginx/sites-enabled/default
echo DONE
