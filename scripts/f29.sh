#!/bin/bash
P=http://localhost:9092
echo "===== notification list GET(user_id query) ====="
curl -s -m 20 "$P/notifications/list?user_id=2697531370768443&size=5" | head -c 400
echo ""
echo "===== bigmodel 代理带 Authorization 透传(列模型) ====="
ZKEY=674ea22cd4af46508ab1baa22d3a6fc6.mSy1BrBipXy3pnoG
curl -s -m 30 "$P/bigmodel/v1/models" -H "Authorization: Bearer $ZKEY" | head -c 250
echo ""
echo "[DONE]"
