#!/usr/bin/env bash
set +e
OUT=/var/www/sylab-ios/diag_sched_0930.txt
bash /tmp/diag_sched.sh > "$OUT" 2>&1
echo "saved bytes=$(wc -c < "$OUT")"
