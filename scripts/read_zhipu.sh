#!/bin/bash
cd /root/coze-studio/tool-proxy
# 找 zhipu_proxy 函数定义
grep -nE "^async def zhipu|^def zhipu|@app.post.*bigmodel" server.py | head
echo "---"
# 找 network_error 动态字符串
grep -n "network_error" server.py | head
echo "---"
# 看 zhipu-proxy 完整函数（假设 2074 起）
sed -n '2060,2200p' server.py
