#!/bin/bash
H='-H Content-Type:application/json -H x-aiplugin-conversation-id:testconv001'
echo "### 同会话连续6次 echo placeholder1（数字归一化后同指纹）###"
for i in 1 2 3 4 5 6; do
  R=$(curl -s -X POST http://127.0.0.1:9097/execute \
    -H 'Content-Type: application/json' \
    -H 'x-aiplugin-conversation-id: testconv001' \
    -d "{\"code\":\"echo placeholder$i\",\"language\":\"shell\"}")
  echo "第$i次 -> code=$(echo "$R" | python3 -c "import json,sys;d=json.load(sys.stdin);print(d.get('code'))" 2>/dev/null)"
done
echo ""
echo "### 第6次返回体 ###"
curl -s -X POST http://127.0.0.1:9097/execute -H 'Content-Type: application/json' -H 'x-aiplugin-conversation-id: testconv001' -d '{"code":"echo placeholder99","language":"shell"}' | python3 -m json.tool 2>/dev/null | grep -E "msg|code|exit"
echo ""
echo "### 换新命令（不同指纹）应放行 code=0 ###"
curl -s -X POST http://127.0.0.1:9097/execute -H 'Content-Type: application/json' -H 'x-aiplugin-conversation-id: testconv001' -d '{"code":"date +%s","language":"shell"}' | python3 -c "import json,sys;d=json.load(sys.stdin);print('code=',d.get('code'),'stdout=',(d.get('data') or {}).get('stdout','').strip())"
echo "[DONE]"
