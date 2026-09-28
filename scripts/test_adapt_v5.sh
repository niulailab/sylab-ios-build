#!/bin/bash

# Login
curl -s -c /tmp/ck.txt -X POST http://localhost:9091/api/passport/web/email/login/ \
  -H 'Content-Type: application/json' \
  -d '{"email":"test@sylab.com","password":"123456"}' > /tmp/login_resp.json
SK=$(grep session_key /tmp/ck.txt | awk '{print $NF}')

# Create conversation with correct endpoint
echo "=== Create conversation ==="
CONV_RESP=$(curl -s -X POST "http://localhost:9091/v1/conversation/create" \
  -H 'Content-Type: application/json' \
  -H "Authorization: Bearer $SK" \
  -d '{"bot_id":"7669580347859795968"}')
echo "$CONV_RESP" | head -c 300
echo ""

CONV_ID=$(echo "$CONV_RESP" | python3 -c "
import json,sys
d=json.load(sys.stdin)
data = d.get('data', d)
print(data.get('conversation_id',data.get('id','')))
" 2>/dev/null)
echo "Conversation: $CONV_ID"

if [ -z "$CONV_ID" ]; then
  echo "FAILED to create conversation"
  exit 1
fi

# External skill
EXT_SKILL='---
name: github-actions-failure-debugging
description: Guide for debugging failing GitHub Actions workflows.
---
1. Use the list_workflow_runs tool to look up recent workflow runs
2. Use the summarize_job_log_failures tool to get AI summary of failed logs
3. Use the get_job_logs or get_workflow_run_logs for full failure logs
4. Try to reproduce the failure yourself
5. Fix the failing build'

# Build payload
PAYLOAD=$(python3 <<PYEOF
import json
prompt = """你是一个技能提炼器。用户给了你一个来自外部平台（GitHub Copilot）的技能，请把它适配成我们平台自己的技能。

要求：
1. 分析这个外部技能依赖的工具
2. 根据我们平台可用的工具，替换成等价或最接近的工具
3. 如果某个外部工具没有直接对应，说明用什么组合方式替代
4. 输出标准 JSON 格式技能

外部技能内容：
$EXT_SKILL

请只输出一个 JSON 对象，格式如下，不要输出其他内容：
{"name":"技能名称","icon":"emoji","category":"分类","trigger":"触发场景","tools":["工具名"],"params":[{"name":"参数名","required":true,"desc":"说明","example":"示例"}],"content":"## 目标\\n...\\n## 输入参数\\n...\\n## 步骤\\n1. ...\\n## 输出\\n...\\n## 约束\\n..."}"""
print(json.dumps({
    "bot_id": "7669580347859795968",
    "conversation_id": "$CONV_ID",
    "user_id": "17857736066221234",
    "stream": True,
    "auto_save_history": True,
    "additional_messages": [{"role":"user","content":prompt,"content_type":"text"}]
}))
PYEOF
)

echo ""
echo "=== Send to v3/chat ==="
curl -s -N \
  "http://localhost:9091/v3/chat" \
  -H 'Content-Type: application/json' \
  -H "Authorization: Bearer $SK" \
  -d "$PAYLOAD" > /tmp/sse_v5.txt 2>&1 &
CPID=$!
sleep 90
kill $CPID 2>/dev/null || true
wait $CPID 2>/dev/null || true

echo ""
echo "=== Raw SSE first 20 lines ==="
head -20 /tmp/sse_v5.txt
echo ""
echo "=== Parsed result ==="
python3 <<'PYEOF'
import json

parts = []
events_seen = set()
with open('/tmp/sse_v5.txt') as f:
    ev = None
    for line in f:
        line = line.strip()
        if line.startswith('event:'):
            ev = line[6:].strip()
            events_seen.add(ev)
        elif line.startswith('data:'):
            ds = line[5:].strip()
            if ds in ('[DONE]',''): continue
            try: d = json.loads(ds)
            except: continue
            if ev == 'conversation.message.delta' and d.get('type') == 'answer':
                parts.append(d.get('content',''))

print("Events seen:", sorted(events_seen))
answer = ''.join(parts)
print("Answer length:", len(answer))
print()
print(answer[:6000])
PYEOF

