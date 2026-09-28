#!/bin/bash
echo "### AFTER restart (container was restarted last run)"
for u in https://www.baidu.com https://www.qq.com https://example.com; do
 docker cp /tmp/_probe.py tool-proxy:/tmp/_probe.py
 docker exec tool-proxy python3 -u /tmp/_probe.py "$u"
done
echo "[DONE]"
