#!/bin/bash
set -e
TS=$(date +%Y%m%d_%H%M%S)
mkdir -p /root/backups
cp /root/coze-studio/tool-proxy/server.py /root/backups/server.py.bak_adaptive_$TS
echo "backup /root/backups/server.py.bak_adaptive_$TS"
python3 /tmp/patch_adaptive.py
python3 -m py_compile /root/coze-studio/tool-proxy/server.py && echo "syntax OK"
docker restart tool-proxy >/dev/null && echo "tool-proxy restarted"
sleep 6
docker logs --tail 8 tool-proxy 2>&1 | tail -8
echo DONE
