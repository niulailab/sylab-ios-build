#!/bin/bash
echo "=== 1) 先 quote 获取报价 ==="
USER_ID=$(docker exec coze-mysql mysql -uroot -pd3G8JG273iE8C4irRWJX opencoze -N -e "SELECT user_id FROM user LIMIT 1;" 2>/dev/null | head -1)
echo "Using user_id: $USER_ID"

QUOTE_RESP=$(curl -s --max-time 15 -X POST "http://127.0.0.1:9092/video/generate" \
  -H "Content-Type: application/json" \
  -H "X-AiPlugin-Connector-Identifier: test" \
  -d "{
    \"action\": \"quote\",
    \"prompt\": \"a cute cat running\",
    \"model\": \"h3-fast\",
    \"duration\": 5,
    \"user_id\": \"$USER_ID\"
  }")
echo "Quote response:"
echo "$QUOTE_RESP" | python3 -m json.tool 2>/dev/null || echo "$QUOTE_RESP"

echo
echo "=== 2) 用 quote 的响应生成视频 ==="
GENERATE_RESP=$(curl -s --max-time 15 -X POST "http://127.0.0.1:9092/video/generate" \
  -H "Content-Type: application/json" \
  -H "X-AiPlugin-Connector-Identifier: test" \
  -d "{
    \"action\": \"generate\",
    \"prompt\": \"a cute cat running\",
    \"model\": \"h3-fast\",
    \"duration\": 5,
    \"user_id\": \"$USER_ID\"
  }")
echo "Generate response:"
echo "$GENERATE_RESP" | python3 -m json.tool 2>/dev/null || echo "$GENERATE_RESP"

echo
echo "=== 3) 查 task_id 对应的视频状态 ==="
TASK_ID=$(echo "$GENERATE_RESP" | python3 -c "import json,sys; d=json.load(sys.stdin); print(json.loads(d.get('data','{}')).get('task_id',''))" 2>/dev/null)
echo "Task ID: $TASK_ID"

if [ -n "$TASK_ID" ] && [ "$TASK_ID" != "" ]; then
  sleep 3
  echo "Checking status..."
  curl -s --max-time 10 "http://127.0.0.1:9092/video/status/$TASK_ID" \
    -H "X-AiPlugin-Connector-Identifier: test" | python3 -m json.tool 2>/dev/null
fi

echo
echo "[DONE]"
