#!/bin/bash
set -euo pipefail
cd /root/coze-studio/tool-proxy
F=server.py
TS=$(date +%Y%m%d_%H%M%S)
cp -p "$F" "${F}.bak_ssere_${TS}"
echo "[1] backed up ${F}.bak_ssere_${TS}"

python3 - <<'PY'
import pathlib, re
p = pathlib.Path("server.py")
src = p.read_text()

# 定位 zhipu_proxy 里 SSE 转发循环：找 httpx.AsyncClient timeout 那段
# 策略：在 except 分支加一个重试包裹。先找"network_error"这个字符串出处（这是 reason）
anchors = [i for i,l in enumerate(src.splitlines()) if "reason=network_error" in l]
print("found network_error at lines:", [a+1 for a in anchors])

# 方案 B：不改现有 except，而是在 zhipu_proxy 外层加一个 "SSE 整体重试包裹"
# 找到 zhipu_proxy 函数定义的入口 async def zhipu_proxy(...) 或 @app.post
# 找到它内部实际调 upstream 的核心循环，在循环外再包一层 for retry in range(N)

# 先找关键 anchor：现有 SSE 读取 try/except 块
# 锚点：找 "reason=network_error" 所在函数
for a in anchors:
    # 向上搜 async def
    for i in range(a, -1, -1):
        if src.splitlines()[i].strip().startswith("async def "):
            fn = src.splitlines()[i].strip()
            print(f"network_error inside function at line {i+1}: {fn}")
            break

# 我们采用最稳的方案：在现有 httpx POST 上游那段加一次重试
# 锚点：找 "zhipu-proxy] POST /bigmodel" 那条 info log 附近的代码块
# 实际做法：找现有 reason 赋值 = "network_error" 的 except 分支，在前面加一个外层重试循环
# 更简单：找到 httpx.AsyncClient 创建处，整个 with client 块外面加 retry loop

# 用精确锚点：找现有的 "except (httpx.ReadTimeout, httpx.ConnectTimeout) as te:" （884行附近）
# 以及它的上层 try 块起始位置
target_line = 880  # 附近
for i,l in enumerate(src.splitlines()):
    if "except (httpx.ReadTimeout, httpx.ConnectTimeout)" in l:
        print("target except at line", i+1)
        # 向上找 try: 起点（最近的 try:）
        for j in range(i, -1, -1):
            if src.splitlines()[j].strip() == "try:":
                print("matching try at line", j+1)
                break
        break
PY
