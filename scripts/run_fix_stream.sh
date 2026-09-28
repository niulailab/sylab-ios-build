#!/bin/bash
set -e
TS=$(date +%Y%m%d_%H%M%S)
cp /root/coze-studio/tool-proxy/server.py /root/backups/server.py.bak_fixstream_$TS
curl -sL "https://raw.githubusercontent.com/niulailab/sylab-ios-build/main/scripts/fix_stream.py" -o /tmp/fix_stream.py
python3 /tmp/fix_stream.py
python3 -m py_compile /root/coze-studio/tool-proxy/server.py && echo "syntax OK"
docker restart tool-proxy >/dev/null && echo restarted
sleep 6
echo DONE
