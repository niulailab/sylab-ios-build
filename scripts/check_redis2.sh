#!/bin/bash
which redis-cli valkey-cli 2>/dev/null
docker inspect coze-redis --format '{{.Config.Image}}'
# host python redis?
python3 - <<'PY'
try:
 import redis; print("redis-py ok")
except Exception as e: print("no redis-py",e)
PY
echo DONE
