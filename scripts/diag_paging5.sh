#!/bin/bash
echo "===== TIME ====="; date
CID=7688397794641444864
echo "===== A) no auth, page1 ====="
curl -s -m 10 -X POST "http://172.18.0.103:8888/v1/conversation/message/list" \
  -H 'Content-Type: application/json' \
  -d "{\"conversation_id\":\"$CID\",\"page_num\":1,\"page_size\":50}" | head -c 800
echo; echo
echo "===== B) via host nginx 9091 no auth page2 ====="
curl -s -m 10 -X POST "http://127.0.0.1:9091/v1/conversation/message/list" \
  -H 'Content-Type: application/json' \
  -d "{\"conversation_id\":\"$CID\",\"page_num\":2,\"page_size\":50}" | head -c 800
echo; echo
echo "===== C) coze-server recent logs mentioning message/list ====="
docker logs --since 30m coze-server 2>&1 | grep -i "message/list\|conversation/message" | tail -20
echo "===== DONE ====="
