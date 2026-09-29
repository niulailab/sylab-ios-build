#!/bin/bash
echo "### A. code_exec_server.js 概览 ###"
wc -l /root/code_exec_server.js
echo "--- 路由/execute/模型上游/thinking 相关行 ---"
grep -nE "/execute|createServer|listen|readFileSync|require\(|process\.env|glm|bigmodel|thinking|model|base_url|openai|chat/completions" /root/code_exec_server.js 2>/dev/null | head -40

echo ""
echo "### B. /root 下可能的模型/连接配置文件 ###"
ls -la /root/*.js /root/*.json /root/*.env /root/.env* 2>/dev/null | grep -viE "sylab-app|node_modules" | head -30

echo ""
echo "### C. coze-studio 全目录搜 100015（排除.bak/.skills）###"
timeout 50 grep -rniE "100015" /root/coze-studio 2>/dev/null | grep -viE "\.bak|\.skills|node_modules|/template/" | head -15

echo "[DONE]"
