#!/bin/bash
set -e
python3 - <<'PY'
p="/root/coze-studio/ADMIN_NOTES.md"
s=open(p,encoding="utf-8").read()
entry="- 2026-09-29（最终状态，覆盖上一条中间态）：经核实 5.3flash 一直在用、flash 始终思考且仅支持 low/high/max 三档（不支持 medium，报错1210）。**最终落地 = 100015: glm-5.3-flash + 智谱直连(open.bigmodel.cn) + thinking_type=1，彻底不走那层 adaptive 代理**；tool-proxy server.py 的 bigmodel 路由改纯透传（不注入任何 reasoning_effort；文件5637行，adaptive标记0处）。当晚真正元凶是 9-28 加的 adaptive 流监控(_watch/tool_only)，已随回退清除。已干净重启 coze-server+tool-proxy，DB=内存一致，flash默认档思考366字实测正常；shell 熔断保留（code_exec_server.js，code-exec systemd active）。备份 /root/backup_revert_20260929_224537/。\n"
anchor="## 8. 变更日志（倒序，每次改动追加一行）"
idx=s.find(anchor); idx2=s.index("\n",idx)+1
s=s[:idx2]+entry+s[idx2:]
open(p,"w",encoding="utf-8").write(s)
print("服务器版已补最终态")
PY
echo "[DONE]"
