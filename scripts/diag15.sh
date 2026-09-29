#!/bin/bash
echo "### 1. 模型请求实际发往的上游URL ###"
docker logs coze-server --since 6h 2>&1 | grep "7ebcc4cb" | grep -oiE "https?://[a-z0-9.-]+[^ \"]*" | grep -viE "tool-proxy|symsgf|36.137" | sort | uniq -c | head

echo ""
echo "### 2. 发给LLM的真实model字段 ###"
docker logs coze-server --since 6h 2>&1 | grep "7ebcc4cb" | grep -oE '"model":"[^"]*"' | sort | uniq -c | head

echo ""
echo "### 3. Balance模式如何影响thinking（源码）###"
grep -rniE "ModelStyle_Balance|Balance|enable_thinking|EnableThinking|reasoning" /root/coze-studio/backend/domain/agent --include=*.go 2>/dev/null | grep -iE "balance|thinking|reason" | grep -viE "_test" | head -20

echo ""
echo "### 4. 对比：其他近期run有没有非空reasoning ###"
docker logs coze-server --since 6h 2>&1 | grep -oE '"reasoning_content":"[^"]{5}' | grep -v '"reasoning_content":""' | wc -l
echo "--- 近期非空reasoning样例 ---"
docker logs coze-server --since 6h 2>&1 | grep -oE '"reasoning_content":"[^"]{0,50}' | grep -v '"reasoning_content":""' | head -3

echo "[DONE]"
