#!/bin/bash
set -e

# Get auth token
TOKEN=$(curl -s -X POST "https://direct.symsgf.xyz:8099/v1/auth/login" \
  -H "Content-Type: application/json" \
  -d '{"username":"admin@sylab.ai","password":"Sylab2026!"}' | python3 -c "import json,sys;print(json.load(sys.stdin).get('data',{}).get('access_token',''))")

if [ -z "$TOKEN" ]; then
  echo "AUTH FAILED"
  exit 1
fi
echo "Auth OK"

# The external skill content (GitHub Copilot github-actions-failure-debugging)
EXTERNAL_SKILL='---
name: github-actions-failure-debugging
description: Guide for debugging failing GitHub Actions workflows. Use this when asked to debug failing GitHub Actions workflows.
---

To debug failing GitHub Actions workflows in a pull request, follow this process, using tools provided from the GitHub MCP Server:

1. Use the `list_workflow_runs` tool to look up recent workflow runs for the pull request and their status
2. Use the `summarize_job_log_failures` tool to get an AI summary of the logs for failed jobs, to understand what went wrong without filling your context windows with thousands of lines of logs
3. If you still need more information, use the `get_job_logs` or `get_workflow_run_logs` tool to get the full, detailed failure logs
4. Try to reproduce the failure yourself in your own environment.
5. Fix the failing build. If you were able to reproduce the failure yourself, make sure it is fixed before committing your changes.'

# Build the prompt asking sylab AI to adapt this to our tools
PROMPT="下面是一个来自外部平台（GitHub Copilot）的技能（Skill），它依赖 GitHub MCP Server 的工具。

请你：
1. 先看看这个技能做什么
2. 对照你自己实际可用的工具，把外部技能引用的工具替换成你这边等价的工具
3. 输出一个适配后的技能 JSON，格式：{\"name\":\"\",\"icon\":\"\",\"category\":\"\",\"trigger\":\"\",\"tools\":[\"你实际有的工具\"],\"params\":[{\"name\":\"\",\"required\":true,\"desc\":\"\",\"example\":\"\"}],\"content\":\"适配后的SOP Markdown\"}
4. 如果某个外部工具没有等价替代，在 content 里标注「待验证」并给出手动方案
5. 只输出 JSON，不要其他解释

外部技能内容：
$EXTERNAL_SKILL"

# Send via v3 chat API (non-stream for easy parsing)
echo "Sending external skill to sylab AI for adaptation..."
RESPONSE=$(curl -s -X POST "https://direct.symsgf.xyz:8099/v3/chat" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d "$(python3 -c "
import json
prompt = '''$PROMPT'''
payload = {
    'bot_id': '7669580347859795968',
    'user_id': 'test_extract_001',
    'stream': False,
    'auto_save_history': False,
    'additional_messages': [
        {'role': 'user', 'content': prompt, 'content_type': 'text'}
    ]
}
print(json.dumps(payload, ensure_ascii=False))
")")

echo "=== RAW RESPONSE ==="
echo "$RESPONSE" | python3 -c "
import json, sys
data = json.load(sys.stdin)
# Try to extract the message content
msg = data.get('data', {}).get('messages', [])
for m in msg:
    if m.get('role') == 'assistant':
        c = m.get('content', '')
        if isinstance(c, str):
            print(c)
        elif isinstance(c, list):
            for part in c:
                if isinstance(part, dict) and part.get('text'):
                    print(part['text'])
        break
else:
    # fallback
    print(json.dumps(data, ensure_ascii=False, indent=2)[:3000])
" 2>/dev/null || echo "$RESPONSE" | head -c 3000

echo ""
echo "=== TEST DONE ==="
