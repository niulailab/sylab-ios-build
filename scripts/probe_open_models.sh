#!/bin/bash
probe(){ echo "-- $1"; curl -s -m 12 -o /tmp/_p.txt -w "%{http_code}\n" "$@"; head -c 400 /tmp/_p.txt; echo; }
# test known existing relays' uncensored-ish endpoints via tool-proxy
echo "=== tool-proxy routes? ==="
for p in bigmodel rjk66 kabuai agnes clawrouter openrouter oneapi newapi; do
 curl -s -m 3 -o /dev/null -w "$p:%{http_code} " "http://tool-proxy:9092/$p/v1/models"
done
echo
echo DONE
