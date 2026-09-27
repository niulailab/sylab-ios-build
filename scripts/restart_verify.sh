#!/bin/bash
docker restart coze-server >/dev/null && echo "coze-server restarted"
# wait health
for i in $(seq 1 20); do
 sleep 3
 if docker logs --tail 5 coze-server 2>&1 | grep -qiE 'start|listen|running'; then echo "up-ish"; fi
done
sleep 5
echo DONE
