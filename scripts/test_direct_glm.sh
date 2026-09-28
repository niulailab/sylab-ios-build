#!/bin/bash

API_KEY="674ea22cd4af46508ab1baa22d3a6fc6.mSy1BrBipXy3pnoG"

# External skill from GitHub Copilot
EXT_SKILL='---
name: github-actions-failure-debugging
description: Guide for debugging failing GitHub Actions workflows.
---
1. Use the `list_workflow_runs` tool to look up recent workflow runs
2. Use the `summarize_job_log_failures` tool to get AI summary of failed logs
3. Use the `get_job_logs` or `get_workflow_run_logs` for full failure logs
4. Try to reproduce the failure yourself
5. Fix the failing build'

# Build request - include system prompt telling it what tools are available
# These are the tools sylab AI actually has
SYSTEM='你是sylab AI平台的技能提炼器。你的任务是把外部平台的技能适配成基于sylab平台自有工具的技能。

sylab平台可用的工具列表：
1. web_search - 联网搜索，支持关键词搜索、时间过滤
2. execute_code - 执行Python代码，支持HTTP请求、文件处理、数据计算
3. github_actions_unified - GitHub Actions统一操作，支持触发工作流、查看运行状态、列出运行记录（action参数：trigger/list_runs/get_run/cancel）
4. image_generate - AI图片生成
5. text_to_speech - 文字转语音
6. vision_analyze - 图片理解分析
7. file_upload - 文件上传
8. memory - 记忆存取

适配规则：
- 外部工具如果有直接等价物，直接替换
- 如果没有直接等价物，用最接近的工具组合实现，并在步骤中说明
- 保留原技能的核心目标和逻辑
- 输出标准JSON格式技能

输出格式（只输出JSON，不要其他内容）：
{"name":"技能名称","icon":"emoji图标","category":"分类","trigger":"触发场景描述","tools":["使用的工具名"],"params":[{"name":"参数名","required":true,"desc":"参数说明","example":"示例值"}],"content":"技能SOP文档，包含：## 目标、## 输入参数、## 步骤（编号列表）、## 输出、## 约束"}'

python3 <<PYEOF
import json, httpx

api_key = "$API_KEY"
ext_skill = """$EXT_SKILL"""
system = '''$SYSTEM'''

user_msg = f"请把以下外部技能适配成sylab平台的技能：\n\n{ext_skill}"

payload = {
    "model": "glm-5.3-flash",
    "messages": [
        {"role": "system", "content": system},
        {"role": "user", "content": user_msg}
    ],
    "stream": False,
    "temperature": 0.3,
    "max_tokens": 4000
}

print("=== Calling GLM via tool-proxy ===")
resp = httpx.post(
    "http://127.0.0.1:9092/bigmodel/v1/chat/completions",
    headers={"Authorization": f"Bearer {api_key}", "Content-Type": "application/json"},
    json=payload,
    timeout=120
)
print(f"Status: {resp.status_code}")
data = resp.json()

# Strip thinking content
content = ""
for choice in data.get("choices", []):
    msg = choice.get("message", {})
    content = msg.get("content", "")
    reasoning = msg.get("reasoning_content", "")
    if reasoning:
        print(f"[reasoning stripped, len={len(reasoning)}]")

print(f"\n=== Response length: {len(content)} ===\n")
print(content[:6000])

# Try to parse as JSON
print("\n\n=== JSON VALIDATION ===")
try:
    # Find JSON in response
    import re
    json_match = re.search(r'\{[^{}]*(?:\{[^{}]*\}[^{}]*)*\}', content, re.DOTALL)
    if json_match:
        skill_json = json.loads(json_match.group())
        print("Valid JSON!")
        print(f"Name: {skill_json.get('name')}")
        print(f"Tools: {skill_json.get('tools')}")
        print(f"Params: {[p.get('name') for p in skill_json.get('params',[])]}")
        print(f"Content preview: {skill_json.get('content','')[:300]}")
    else:
        # Try full parse
        skill_json = json.loads(content)
        print("Valid JSON (full parse)!")
except json.JSONDecodeError as e:
    print(f"JSON parse error: {e}")
    # Try repair
    print("Attempting repair...")
PYEOF

