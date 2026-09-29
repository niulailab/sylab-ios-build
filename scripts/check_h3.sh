#!/bin/bash
SP=/root/coze-studio/tool-proxy/server.py
echo "=== 1) video_generate_v2 本体（5432起，真实 H3 链路）==="
sed -n '5432,5548p' $SP | grep -nE "http|url|URL|runninghub|h3|H3|api|endpoint|def |action|tier|prompt|return|error|post|POST|director|导演" | head -45
echo
echo "=== 2) H3 上游常量定义 ==="
grep -nE "H3.*=|RUNNINGHUB|runninghub.*=|h3-fast|h3_fast|director.*url|导演脚本|RH_API" $SP | head -20
echo
echo "=== 3) 最近视频生成相关日志（找 sylab 那3次空返回）==="
docker logs tool-proxy --since 6h 2>&1 | grep -iE "video|h3|runninghub|导演|generate" | tail -30
echo
echo "=== 4) 旧 YanBa 函数体是否真无路由指向（确认死代码）==="
grep -nE "video_generate[^_]|YANBA_API_URL" $SP | head
echo "[DONE]"
