#!/bin/bash
echo "===== nginx root / alias for the download location ====="
grep -nE "sylab-unsigned|\.ipa" /etc/nginx/sites-enabled/default | head
echo
echo "===== locate real current ipa files with size/mtime ====="
find / -name '*.ipa' -not -path '*/v108-old*' 2>/dev/null -exec ls -la {} \; | sort -k6,7 | tail -20