#!/bin/bash
set -e
TS=$(date +%Y%m%d_%H%M%S)
mkdir -p /root/backup_circuit_$TS

CES=/root/code_exec_server.js
TP=/root/coze-studio/tool-proxy/server.py
cp "$CES" /root/backup_circuit_$TS/code_exec_server.js.bak
cp "$TP"  /root/backup_circuit_$TS/server.py.bak
echo "备份目录: /root/backup_circuit_$TS"

python3 - <<'PY'
ces="/root/code_exec_server.js"
s=open(ces,encoding="utf-8").read()

# 1) helper：归一化 shell 命令指纹 + 连续计数（幂等）
helper = '''
// ---------- SHELL SPIN CIRCUIT BREAKER (20260929) ----------
const _shellSpin = new Map(); // key -> {sig, count}
function _shellSig(code) {
  let c = String(code || "");
  // 去掉注释行
  c = c.split("\\n").map(l => l.replace(/^\\s*#.*$/, "")).join("\\n");
  // 归一化：所有数字->N，空白折叠，小写，去引号
  c = c.replace(/[0-9]+/g, "N").replace(/["'`]/g, "").replace(/\\s+/g, " ").trim().toLowerCase();
  return c;
}
function shellSpinCheck(sessionId, code) {
  const key = String(sessionId || "default");
  const sig = _shellSig(code);
  if (!sig) return { tripped: false };
  const e = _shellSpin.get(key) || { sig, count: 0 };
  if (e.sig === sig) { e.count += 1; } else { e.sig = sig; e.count = 1; }
  _shellSpin.set(key, e);
  if (_shellSpin.size > 5000) { const k = _shellSpin.keys().next().value; _shellSpin.delete(k); }
  return { tripped: e.count >= 5, count: e.count };
}
// ---------- END CIRCUIT BREAKER ----------
'''
if "SHELL SPIN CIRCUIT BREAKER" not in s:
    anchor="const server = http.createServer"
    idx=s.find(anchor)
    if idx<0: raise SystemExit("anchor http.createServer not found")
    s=s[:idx]+helper+"\n"+s[idx:]
    print("helper inserted")
else:
    print("helper already present")

# 2) 在拿到 sessionId/execWorkspace 之后插入检查（幂等）
check = '''      // ---- shell 空转熔断：同会话归一化后连续重复命令即拦 ----
      if (['shell','bash','sh'].includes((parsed.language||'').toLowerCase())) {
        const sc = shellSpinCheck(sessionId, code);
        if (sc.tripped) {
          console.log('[circuit] TRIPPED session=' + sessionId + ' count=' + sc.count);
          res.statusCode = 429;
          return res.end(JSON.stringify({ code: 429, msg: 'Circuit breaker: 这条 shell 命令归一化后已在本会话连续重复 ' + sc.count + ' 次，判定为空转。立即停止重复执行，不要再用 shell 试探；改用你已绑定的专用工具（如 video_generate 等）完成任务。', data: { stdout: '', stderr: 'circuit_breaker_duplicate_shell', exit_code: -3 } }));
        }
      }
'''
if "circuit] TRIPPED" not in s:
    a="if (!fs.existsSync(execWorkspace)) fs.mkdirSync(execWorkspace, { recursive: true });"
    idx=s.find(a)
    if idx<0: raise SystemExit("workspace anchor not found")
    idx2=s.index("\n",idx)+1
    s=s[:idx2]+check+s[idx2:]
    print("check inserted")
else:
    print("check already present")

open(ces,"w",encoding="utf-8").write(s)

# 3) tool-proxy：去掉强制 reasoning_effort=low 注入
tp="/root/coze-studio/tool-proxy/server.py"
t=open(tp,encoding="utf-8").read()
old='''            if isinstance(payload, dict):
                payload["reasoning_effort"] = "low"
                body = json.dumps(payload, ensure_ascii=False).encode("utf-8")'''
new='''            if isinstance(payload, dict):
                # 20260929: 不再强制 low（会压制思考致空转）；仅在调用方未指定时给默认 medium
                if "reasoning_effort" not in payload:
                    payload["reasoning_effort"] = "medium"
                body = json.dumps(payload, ensure_ascii=False).encode("utf-8")'''
if old in t:
    t=t.replace(old,new); print("tool-proxy low->default medium")
elif "不再强制 low" in t:
    print("tool-proxy already patched")
else:
    raise SystemExit("tool-proxy inject block not found")
open(tp,"w",encoding="utf-8").write(t)
PY

echo "--- node 语法校验 ---"
node --check "$CES" && echo "code_exec_server.js 语法OK"
python3 -c "import ast; ast.parse(open('$TP',encoding='utf-8').read()); print('server.py 语法OK')"
echo "[DONE]"
