#!/bin/bash
F=/root/coze-studio/llm-proxy/llm_proxy.py
echo "lines: $(wc -l < $F)"
echo "=== structure: defs/classes/routes/providers/key handling ==="
grep -nE "^def |^async def |^class |@app\.|PROVIDER|provider|base_url|api_key|API_KEY|CHANNEL|channel|def forward|chat/completions|Authorization|encrypt" "$F" | head -70
echo "[DONE]"
