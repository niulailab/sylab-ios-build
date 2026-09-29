#!/bin/bash
MP=$(docker exec coze-mysql printenv MYSQL_ROOT_PASSWORD)
echo "### 1. Go后端 thinking_type 语义与转换 ###"
timeout 50 grep -rniE "thinking_type|ThinkingType" /root/coze-studio/backend --include=*.go 2>/dev/null | grep -viE "_test|\.bak" | head -25
echo ""
echo "### 2. tool-proxy server.py 里 bigmodel 代理路由 ###"
grep -nE "bigmodel|/bigmodel/v1|thinking" /root/coze-studio/tool-proxy/server.py 2>/dev/null | head -20
echo ""
echo "### 3. cot_display 在Go里的作用 ###"
timeout 40 grep -rniE "cot_display|CotDisplay|COTDisplay" /root/coze-studio/backend --include=*.go 2>/dev/null | grep -viE "_test|\.bak" | head -12
echo "[DONE]"
