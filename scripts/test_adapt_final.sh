#!/bin/bash

# Login
curl -s -c /tmp/ck.txt -X POST http://localhost:9091/api/passport/web/email/login/ \
  -H 'Content-Type: application/json' \
  -d '{"email":"test@sylab.com","password":"123456"}' > /dev/null
SK=$(grep session_key /tmp/ck.txt | awk '{print $NF}')

# External skill content - GitHub Actions failure debugging
EXT_SKILL='---
name: github-actions-failure-debugging
description: Guide for debugging failing GitHub Actions workflows.
---
1. Use the `list_workflow_runs` tool to look up recent workflow runs
2. Use the `summarize_job_log_failures` tool to get AI summary of failed logs
3. Use the `get_job_logs` or `get_workflow_run_logs` for full failure logs
4. Try to reproduce the failure yourself
5. Fix the failing build'

# Build the prompt - same approach as skillExtract.ts buildPrompt
# The key: ask AI to adapt external skill to our available tools
read -r -d '' PROMPT <<EOF
你是一个技能提炼器。用户给了你一个来自外部平台（GitHub Copilot）的技能，请把它适配成我们平台自己的技能。

要求：
1. 分析这个外部技能依赖的工具
2. 根据我们平台可用的工具，替换成等价或最接近的工具
3. 如果某个外部工具没有直接对应，说明用什么组合方式替代
4. 输出标准 JSON 格式技能

外部技能内容：
$EXT_SKILL

请只输出一个 JSON 对象，格式如下，不要输出其他内容：
{"name":"技能名称","icon":"emoji图标","category":"分类","trigger":"触发场景描述","tools":["使用的工具名"],"params":[{"name":"参数名","required":true,"desc":"参数说明","example":"示例值"}],"content":"## 目标\\n...\\n## 输入参数\\n...\\n## 步骤\\n1. ...\\n## 输出\\n...\\n## 约束\\n..."}
EOF

# Create a conversation first
echo "=== Create conversation ==="
CONV_RESP=$(curl -s -b "session_key=$SK" -X POST "http://localhost:9091/api/conversation/create" \
  -H 'Content-Type: application/json' \
  -d '{"bot_id":"7669580347859795968"}')
echo "$CONV_RESP" | head -c 300
echo ""

CONV_ID=$(echo "$CONV_RESP" | python3 -c "
import json,sys
d=json.load(sys.stdin)
print(d.get('data',{}).get('conversation_id',d.get('conversation_id','')))
" 2>/dev/null)
echo "Conversation: $CONV_ID"

# Send chat message (non-stream for simplicity, but v3 uses SSE)
echo ""
echo "=== Send skill adaptation request ==="
PAYLOAD=$(python3 -c "
import json
prompt = '''$PROMPT'''
print(json.dumps({
    'bot_id': '7669580347859795968',
    'conversation_id': '$CONV_ID',
    'user_id': '17857736066221234',
    'stream': True,
    'auto_save_history': True,
    'additional_messages': [{
        'role': 'user',
        'content': prompt,
        'content_type': 'text'
    }]
}))
")

curl -s -N -b "session_key=$SK" \
  "http://localhost:9091/v3/chat" \
  -H 'Content-Type: application/json' \
  -H "Authorization: Bearer $SK" \
  -d "$PAYLOAD" > /tmp/sse_output.txt 2>&1 &
CURL_PID=$!

# Wait up to 60 seconds
sleep 60
kill $CURL_PID 2>/dev/null || true

echo ""
echo "=== SSE Output (parsed) ==="
python3 <<'PYEOF'
import json, re

content_parts = []
tool_calls = []
full_event = {}

with open('/tmp/sse_output.txt') as f:
    event_type = None
    for line in f:
        line = line.strip()
        if line.startswith('event:'):
            event_type = line.split(':',1)[1].strip()
        elif line.startswith('data:'):
            data_str = line[5:].strip()
            if data_str == '[DONE]':
                continue
            try:
                data = json.loads(data_str)
            except:
                continue
            
            if event_type == 'conversation.message.delta':
                msg_type = data.get('type')
                content = data.get('content','')
                if msg_type == 'answer':
                    content_parts.append(content)
                elif msg_type == 'tool_response':
                    tool_calls.append(content[:200])
            elif event_type == 'conversation.message.completed':
                full_event[data.get('type','')] = data.get('content','')

full_content = ''.join(content_parts)
print("=== ANSWER LENGTH ===")
print(len(full_content))
print()
print("=== FULL ANSWER ===")
print(full_content[:5000])
print()
if tool_calls:
    print("=== TOOL RESPONSES ===")
    for t in tool_calls[:3]:
        print(t[:300])
        print("---")
PYEOF

