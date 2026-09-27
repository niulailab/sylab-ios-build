#!/usr/bin/env bash
set +e
F=/etc/nginx/sites-enabled/default
echo "=====DEFAULT_B64_START====="
base64 -w0 "$F"
echo
echo "=====DEFAULT_B64_END====="
echo "DUMP_DEFAULT_DONE"
