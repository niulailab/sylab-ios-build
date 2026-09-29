#!/bin/bash
echo "### 1. 所有 conn_100015 配置文件 ###"
ls -la /root/conn_100015* 2>/dev/null
echo ""
for f in /root/conn_100015*.json; do
  echo "--- $f ---"
  python3 -c "import json;d=json.load(open('$f'));o=d.get('openai',d);b=d.get('base_conn_info',{});print('model:',o.get('model'),'| base_url:',o.get('base_url'),'| thinking_type:',b.get('thinking_type'))" 2>/dev/null
done
echo ""
echo "### 2. code_exec_server.js 里当前如何读100015/thinking ###"
grep -nE "100015|thinking_type|conn_100015" /root/code_exec_server.js 2>/dev/null | head -10
echo "[DONE]"
