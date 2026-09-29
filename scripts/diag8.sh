#!/bin/bash
docker logs coze-server --since 5h 2>&1 | grep "7ebcc4cb" > /tmp/rl.txt

echo "### 1. 全部命令body按顺序（前25个）###"
grep "invocation_http.go" /tmp/rl.txt | grep -oE "body=.*" | head -25

echo ""
echo "### 2. run_command 的返回结果（前6个 OnResult/resp）###"
grep -iE "OnResult|run_command.*result|resp.*placeholder|stdout" /tmp/rl.txt | grep -oE "(stdout|result|output)[\":=]*[^,}]{0,60}" | head -12

echo ""
echo "### 3. 进入工具循环前模型的reasoning ###"
grep -oE '"reasoning[^"]*":"[^"]{0,400}' /tmp/rl.txt | head -8

echo ""
echo "### 4. 该run最初的用户输入/OnStart ###"
grep -iE "OnStart.*react|user.*content|测试开始|placeholder" /tmp/rl.txt | head -5 | cut -c1-400

echo "[DONE]"
