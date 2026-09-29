#!/bin/bash
set -euo pipefail
cd /root/coze-studio/tool-proxy
F=server.py
TS=$(date +%Y%m%d_%H%M%S)

# 1) 备份
cp -p "$F" "${F}.bak_monitor_${TS}"
echo "[1] backed up ${F}.bak_monitor_${TS}"

# 2) 用 python 精确替换 _watch_final 的两个关键参数：
#    ① 轮询次数 60 -> 180（总时长 10min -> 30min）
#    ② 超时时不再直接判 failed，改为"二次确认"：再查一次会话内最新一条 bot 消息 / 查 status-by-uuid 兜底
python3 - <<'PY'
import re, pathlib
p = pathlib.Path("server.py")
src = p.read_text()

# ① 轮询 60 -> 180
old = "for _i in range(60):          # 最多约 10 分钟"
new = "for _i in range(180):         # 最多约 30 分钟（长任务产线如教程量产常需 10~15 分钟）"
assert old in src, "range(60) anchor not found"
src = src.replace(old, new)

# ② 超时兜底：把直接判 failed 改为二次补偿
old2 = (
"        if final_status is None:\n"
"            final_status = \"failed\"\n"
"            detail = \"等待执行结果超时\""
)
new2 = (
"        if final_status is None:\n"
"            # 二次补偿：超时不是死刑，先再查一次 status-by-uuid，避免\"活干完只比超时线晚几秒\"被误判 failed\n"
"            recovered = False\n"
"            try:\n"
"                async with httpx.AsyncClient(timeout=httpx.Timeout(15.0, connect=5.0)) as c2:\n"
"                    r2 = await c2.post(\n"
"                        STATUS_URL, json={\"task_uuid\": task_uuid},\n"
"                        headers={\"X-Internal-Key\": FIRE_KEY, \"Content-Type\": \"application/json\"})\n"
"                    d2 = r2.json()\n"
"                if d2.get(\"found\"):\n"
"                    st2 = d2.get(\"status\", \"\")\n"
"                    if st2 == \"completed\":\n"
"                        final_status = \"success\"\n"
"                        recovered = True\n"
"                    elif st2 == \"failed\":\n"
"                        final_status = \"failed\"\n"
"                        detail = (d2.get(\"error\") or \"执行失败\")[:300]\n"
"                        recovered = True\n"
"            except Exception as e:\n"
"                logging.warning(f\"[scheduler] recovery probe error task={task_uuid}: {e}\")\n"
"            if not recovered:\n"
"                final_status = \"failed\"\n"
"                detail = \"等待执行结果超时（已二次补偿仍未发现终态）\""
)
assert old2 in src, "timeout fallback anchor not found"
src = src.replace(old2, new2)

p.write_text(src)
print("[2] patched _watch_final: 60->180 + 二次补偿")
PY

# 3) py_compile 校验
python3 -c "import py_compile; py_compile.compile('$F', doraise=True)" && echo "[3] py_compile OK"

# 4) 重启 tool-proxy
cd /root/coze-studio/tool-proxy
# 当前进程通过 systemd 或 supervisor 拉起？先看
ls /etc/systemd/system/ | grep -i tool-proxy || true
ls /etc/supervisor/conf.d/ 2>/dev/null | grep -i tool || true
ps -ef | grep -E "tool-proxy|server.py" | grep -v grep | head -5
