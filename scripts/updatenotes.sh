#!/bin/bash
set -e
cp /root/coze-studio/ADMIN_NOTES.md /root/coze-studio/ADMIN_NOTES.md.bak_$(date +%Y%m%d_%H%M%S)
python3 - <<'PY'
p="/root/coze-studio/ADMIN_NOTES.md"
s=open(p,encoding="utf-8").read()

entry="- `date +%Y-%m-%d`：**修复LLM空转 + 加熔断**。①根因：model_instance id=100015 被切成 glm-5.3-flash 且 tool-proxy 对 /bigmodel/v1 强制注入 reasoning_effort=low，思考被压没致工具选择退化（18:00 跑满200步全是 echo placeholder/curl，没用已绑定的6个video工具）。②改回 100015=智谱直连 glm-5.3 标准版 + thinking_type=1 + cot_display=true（备份 /root/backup_model100015_20260929_212349/）。③tool-proxy 去强制 low，改未指定时默认 medium。④code_exec_server.js 加 shell 空转熔断：同会话命令归一化（数字->N、去注释/引号/空白）连续重复5次即返429，指纹变即清零；视频工具及正常curl/轮询不受影响（备份 /root/backup_circuit_20260929_213232/）。⑤重启：systemctl restart code-exec（注意先杀PPID=1孤儿 node 释放9097）、docker restart tool-proxy coze-server（清fallbackCache模型缓存）。验证：reasoning_content恢复(512字)、熔断第5次429、换命令放行。\n"

anchor="## 8. 变更日志（倒序，每次改动追加一行）"
idx=s.find(anchor)
idx2=s.index("\n",idx)+1
s=s[:idx2]+entry+s[idx2:]
open(p,"w",encoding="utf-8").write(s)
print("变更日志已追加")
PY
echo "### 确认 ###"
grep -n "修复LLM空转" /root/coze-studio/ADMIN_NOTES.md
echo "[DONE]"
