#!/bin/bash
set -e
cd /root/coze-studio/tool-proxy

# Find the latest backup before adaptive patch
BAK=$(ls -t /root/backups/server.py.bak_strip_* 2>/dev/null | head -1)
if [ -z "$BAK" ]; then
  BAK=$(ls -t /root/backups/server.py.bak_fixstream_* 2>/dev/null | head -1)
fi

if [ -z "$BAK" ]; then
  echo "No suitable backup found"
  exit 1
fi

echo "Restoring from: $BAK"
cp "$BAK" /root/coze-studio/tool-proxy/server.py

# Verify syntax
python3 -m py_compile /root/coze-studio/tool-proxy/server.py
echo "Syntax OK"

# Restart
docker restart tool-proxy
echo "Restarted"
sleep 3
docker ps | grep tool-proxy
