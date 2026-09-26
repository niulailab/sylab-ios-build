#!/bin/bash
echo "===== s.symsgf.xyz server block ====="
nginx -T 2>/dev/null | awk '/s.symsgf.xyz direct-origin/{f=1} f{print} f&&/^    }/{c++; if(c>=1) exit}'
echo
echo "===== ssl files used by s block ====="
nginx -T 2>/dev/null | grep -E "ssl_certificate" | grep -iE "s\.|sylab" | head
