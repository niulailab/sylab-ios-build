#!/bin/bash
echo "### model_style 如何映射到思考参数（全backend轻量搜）###"
timeout 50 grep -rniE "ModelStyle_Balance|ModelStyle_Precise|ModelStyle_Creative" /root/coze-studio/backend --include=*.go 2>/dev/null | grep -viE "bot_common.go|_test|String\(\)|FromString|case ModelStyle|return \"" | head -15

echo ""
echo "--- model_style 被读取/转换的地方 ---"
timeout 50 grep -rniE "model_style|ModelStyle" /root/coze-studio/backend --include=*.go 2>/dev/null | grep -iE "thinking|reason|temperature|switch|param" | grep -viE "_test" | head -15

echo ""
echo "### 9097端口是什么服务(LLM实际走这里) ###"
ss -ltnp 2>/dev/null | grep 9097 || docker ps --format '{{.Names}} | {{.Ports}}' | grep 9097

echo "[DONE]"
