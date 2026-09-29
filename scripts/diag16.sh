#!/bin/bash
docker logs coze-server --since 6h 2>&1 > /tmp/full.log
echo "### A. 目标run 真实LLM请求（抓含model/thinking的请求体）###"
grep "7ebcc4cb" /tmp/full.log | grep -iE "thinking|\"model\"|chat/completions|reasoning_effort" | head -8 | cut -c1-500

echo ""
echo "### B. coze-video-service:8960 是什么（目标run访问了它）###"
docker ps --format '{{.Names}}\t{{.Image}}\t{{.Ports}}' | grep -iE "video|8960"

echo ""
echo "### C. 该run第一次工具调用前后，模型请求的完整参数 ###"
grep "7ebcc4cb" /tmp/full.log | grep -iE "Req|request|payload|body" | grep -iE "model|thinking|stream" | head -3 | cut -c1-600

echo ""
echo "### D. 精确统计目标run非空reasoning（python）###"
python3 - <<'PY'
import re
lines=[l for l in open('/tmp/full.log',errors='ignore') if '7ebcc4cb' in l]
nonempty=0; total=0
for l in lines:
    for m in re.finditer(r'"reasoning_content":"((?:[^"\\]|\\.)*)"', l):
        total+=1
        if m.group(1).strip(): nonempty+=1
print("目标run reasoning: total=%d nonempty=%d"%(total,nonempty))
# 找模型真实名字
for l in lines:
    for mm in re.finditer(r'"model"\s*:\s*"([^"]+)"', l):
        print("model field:", mm.group(1)); break
    else: continue
    break
PY

echo "[DONE]"
