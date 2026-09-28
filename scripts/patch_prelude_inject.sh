#!/bin/bash
# BUG2 注入改可靠方案：直接前置 prelude 到用户 Python 脚本顶部
set -e
F=/root/code_exec_server.js
TS=$(date +%Y%m%d_%H%M%S)
cp "$F" "${F}.bak_prelude_${TS}"
echo "backup -> ${F}.bak_prelude_${TS}"

cat > /tmp/_prelude.py <<'PY'
# ===== SANDBOX FILE HELPERS (auto-prepended) =====
import os as _os, json as _json
import urllib.request as _u, urllib.parse as _up
_FILE_SERVICE = _os.environ.get("FILE_SERVICE", "http://127.0.0.1:9093")
_PUBLIC_BASE = "https://s.symsgf.xyz/project-files"
_SANDBOX_CONV = _os.environ.get("SANDBOX_CONVERSATION_ID", "sbx_default")
def _conv_id(c=None):
    return c or _SANDBOX_CONV
def upload_file(file_path, object_name=None, conversation_id=None):
    cid = _conv_id(conversation_id)
    name = (object_name or _os.path.basename(file_path)).replace("/", "_").replace("\\", "_")
    with open(file_path, "rb") as _fh:
        _data = _fh.read()
    _r = _u.Request(_FILE_SERVICE + "/api/files/upload", data=_data, method="POST")
    _r.add_header("X-Conversation-Id", cid)
    _r.add_header("X-File-Name", _up.quote(name))
    with _u.urlopen(_r, timeout=30) as _resp:
        _j = _json.loads(_resp.read().decode())
    if _j.get("code") == 0 and _j.get("data", {}).get("url"):
        return {"code": 0, "msg": "success",
                "url": _PUBLIC_BASE + _j["data"]["url"],
                "name": _j["data"].get("name"), "size": _j["data"].get("size")}
    return {"code": 1, "msg": str(_j)[:200]}
def list_files(conversation_id=None):
    cid = _conv_id(conversation_id)
    _url = _FILE_SERVICE + "/api/files?conversation_id=" + _up.quote(cid)
    with _u.urlopen(_url, timeout=30) as _resp:
        _j = _json.loads(_resp.read().decode())
    if _j.get("code") == 0:
        return {"code": 0, "msg": "success",
                "files": _j["data"].get("files", []), "total": _j["data"].get("total", 0)}
    return {"code": 1, "msg": str(_j)[:200]}
def download_file(filename, save_path=None, conversation_id=None):
    cid = _conv_id(conversation_id)
    _url = _FILE_SERVICE + "/api/files/" + _up.quote(cid) + "/" + _up.quote(filename)
    _dst = save_path or filename
    with _u.urlopen(_url, timeout=60) as _resp, open(_dst, "wb") as _out:
        _out.write(_resp.read())
    return {"code": 0, "msg": "success", "path": _dst}
# ===== END HELPERS =====
PY

PL_B64=$(base64 -w0 /tmp/_prelude.py)

python3 - "$F" "$PL_B64" <<'PY'
import sys, base64, re
f=sys.argv[1]
pl=base64.b64decode(sys.argv[2]).decode()
pl_b64=sys.argv[2]
lines=open(f,encoding="utf-8").read().split('\n')

# 替换整个 executePython
out=[]; i=0; done=False
while i < len(lines):
    if (not done) and re.match(r'async function executePython\(', lines[i]):
        j=i+1
        while j < len(lines) and lines[j].strip() != '}':
            j+=1
        newfn='''async function executePython(code, tempPath, execCwd, timeoutSec = 1800, conversationId) {
  const prelude = Buffer.from("''' + pl_b64 + '''", "base64").toString("utf-8");
  // 直接前置工具函数，保证 100% 可用，不依赖 sitecustomize 自动导入
  fs.writeFileSync(tempPath, prelude + "\\n" + code);
  const cid = (conversationId || 'default').replace(/[^a-zA-Z0-9_-]/g, '');
  const env = Object.assign({}, process.env, {
    FILE_SERVICE: 'http://127.0.0.1:9093',
    SANDBOX_CONVERSATION_ID: 'sbx_' + cid,
  });
  const opts = { timeout: timeoutSec, env: env };
  if (execCwd) opts.cwd = execCwd;
  return runCmd('python3', [tempPath], opts);
}'''
        out.append(newfn); i=j+1; done=True; continue
    out.append(lines[i]); i+=1
assert done
open(f,"w",encoding="utf-8").write('\n'.join(out))
print("patched OK")
PY

node --check "$F" && echo "node --check OK"

# 清理旧 pyinj 缓存（自建临时目录，安全）
rm -rf /tmp/pyinj_* 2>/dev/null || true

# 干净重启（杀掉全部旧实例再起一个）
pkill -f "code_exec_server.js" 2>/dev/null || true
sleep 2
nohup node "$F" > /root/code_exec_server.log 2>&1 &
sleep 5
ss -ltnp 2>/dev/null | grep ':9097' || echo "WARN no listener"
echo "[DONE]"
