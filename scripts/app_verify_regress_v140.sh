#!/bin/bash
cd /root/sylab-app/app/\(tabs\)
CUR=profile.tsx
BAK=$(ls -t profile.tsx.bak_v140_* | head -1)
echo "backup=$BAK"
echo ""
echo "=== line 74 current ==="; sed -n '74p' "$CUR"
echo "=== line 74 backup ==="; sed -n '74p' "$BAK"
echo ""
echo "=== line 200 current ==="; sed -n '200p' "$CUR"
echo "=== line 200 backup ==="; sed -n '200p' "$BAK"
echo ""
echo "=== diff current vs backup (should only show our added lines) ==="
diff "$BAK" "$CUR"
echo "[DONE]"
