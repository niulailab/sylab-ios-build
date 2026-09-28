#!/bin/bash
# BUG2 根治：为 Python 沙箱注入真实 upload_file/list_files/download_file（指向 9093 文件服务）
set -e
F=/root/code_exec_server.js
TS=$(date +%Y%m%d_%H%M%S)
cp "$F" "${F}.bak_inject_${TS}"
echo "backup -> ${F}.bak_inject_${TS}"

# sitecustomize.py 内容（Python 注入 prelude）
cat > /tmp/_sitecustomize.py <<'PY'
# AUTO-INJECTED sandbox file helpers (do not edit).
import os as _os, json as _json, urllib.request as _u, urllib.parse as _up

_FILE_SERVICE = _os.environ.get("FILE_SERVICE", "http://127.0.0.1:9093")
_PUBLIC_BASE = "https://s.symsgf.xyz/project-files"
_SANDBOX_CONV = _os.environ.get("SANDBOX_CONVERSATION_ID", "sbx_default")


def _conv_id(conv_id=None):
    return conv_id or _SANDBOX_CONV


def upload_file(file_path, object_name=None, conversation_id=None):
    """上传本地文件到持久存储，返回可公网访问的下载链接。"""
    cid = _conv_id(conversation_id)
    name = object_name or _os.path.basename(file_path)
    name = name.replace("/", "_").replace("\\", "_")
    with open(file_path, "rb") as fh:
        data = fh.read()
    req = _u.Request(_FILE_SERVICE + "/api/files/upload", data=data, method="POST")
    req.add_header("X-Conversation-Id", cid)
    req.add_header("X-File-Name", _up.quote(name))
    with _u.urlopen(req, timeout=30) as r:
        j = _json.loads(r.read().decode())
    if j.get("code") == 0 and j.get("data", {}).get("url"):
        url = _PUBLIC_BASE + j["data"]["url"]
        return {"code": 0, "msg": "success", "url": url,
                "name": j["data"].get("name"), "size": j["data"].get("size")}
    return {"code": 1, "msg": str(j)[:200]}


def list_files(conversation_id=None):
    """列出当前会话持久存储中的文件。"""
    cid = _conv_id(conversation_id)
    url = _FILE_SERVICE + "/api/files?conversation_id=" + _up.quote(cid)
    with _u.urlopen(url, timeout=30) as r:
        j = _json.loads(r.read().decode())
    if j.get("code") == 0:
        return {"code": 0, "msg": "success",
                "files": j["data"].get("files", []), "total": j["data"].get("total", 0)}
    return {"code": 1, "msg": str(j)[:200]}


def download_file(filename, save_path=None, conversation_id=None):
    """下载持久存储中的文件到本地，返回本地保存路径。"""
    cid = _conv_id(conversation_id)
    url = _FILE_SERVICE + "/api/files/" + _up.quote(cid) + "/" + _up.quote(filename)
    dst = save_path or filename
    with _u.urlopen(url, timeout=60) as r, open(dst, "wb") as out:
        out.write(r.read())
    return {"code": 0, "msg": "success", "path": dst}
PY

SC_B64=$(base64 -w0 /tmp/_sitecustomize.py)

# 新的 executePython（修正 opts bug + 注入 sitecustomize + 传会话环境）
cat > /tmp/_newfn.js <<JS
async function executePython(code, tempPath, execCwd, timeoutSec = 1800, conversationId) {
  fs.writeFileSync(tempPath, code);
  const injDir = path.join(require('os').tmpdir(), 'pyinj_' + process.pid);
  try { fs.mkdirSync(injDir, { recursive: true }); } catch (e) {}
  try {
    fs.writeFileSync(path.join(injDir, 'sitecustomize.py'),
      Buffer.from("${SC_B64}", "base64"));
  } catch (e) {}
  const cid = (conversationId || 'default').replace(/[^a-zA-Z0-9_-]/g, '');
  const env = Object.assign({}, process.env, {
    PYTHONPATH: injDir + (process.env.PYTHONPATH ? (require('path').delimiter + process.env.PYTHONPATH) : ''),
    FILE_SERVICE: 'http://127.0.0.1:9093',
    SANDBOX_CONVERSATION_ID: 'sbx_' + cid,
  });
  const opts = { timeout: timeoutSec, env: env };
  if (execCwd) opts.cwd = execCwd;
  return runCmd('python3', [tempPath], opts);
}
JS

NEWFN_B64=$(base64 -w0 /tmp/_newfn.js)

python3 - "$F" "$NEWFN_B64" <<'PY'
import sys, base64
f=sys.argv[1]
newfn=base64.b64decode(sys.argv[2]).decode()
s=open(f,encoding="utf-8").read()

old='''async function executePython(code, tempPath, execCwd, timeoutSec = 1800) {
  fs.writeFileSync(tempPath, code);
  if (execCwd) opts.cwd = execCwd;
  return runCmd('python3', [tempPath], opts);
}'''
assert s.count(old)==1, "old executePython not unique/found"
s=s.replace(old,newfn,1)

# runCmd 透传 opts.env
runcmd_old='''    const proc = exec(`${cmd} ${args.join(' ')}`, {
      cwd: opts.cwd || WORKSPACE,
      timeout: (opts.timeout || 1800) * 1000,
      maxBuffer: 50 * 1024 * 1024,
    }, (error, stdout, stderr) => {'''
runcmd_new='''    const proc = exec(`${cmd} ${args.join(' ')}`, {
      cwd: opts.cwd || WORKSPACE,
      timeout: (opts.timeout || 1800) * 1000,
      maxBuffer: 50 * 1024 * 1024,
      ...(opts.env ? { env: opts.env } : {}),
    }, (error, stdout, stderr) => {'''
assert s.count(runcmd_old)==1, "runCmd block not unique/found"
s=s.replace(runcmd_old,runcmd_new,1)

# 调用处传入 conversationId（execute 路由里变量名是 sessionId）
call_old="case 'python': case 'python3': case 'py': result = await executePython(code, tempPath, execWorkspace, timeout); break;"
call_new="case 'python': case 'python3': case 'py': result = await executePython(code, tempPath, execWorkspace, timeout, sessionId); break;"
assert s.count(call_old)==1, "executePython call site not unique/found"
s=s.replace(call_old,call_new,1)

open(f,"w",encoding="utf-8").write(s)
print("patched OK")
PY

node --check "$F" && echo "node --check OK"

# 重启 node sandbox
OLD=$(ss -ltnp 2>/dev/null | grep ':9097' | grep -oE 'pid=[0-9]+' | head -1 | cut -d= -f2)
echo "old node pid: $OLD"
nohup node "$F" > /root/code_exec_server.log 2>&1 &
sleep 4
[ -n "$OLD" ] && kill "$OLD" 2>/dev/null || true
sleep 3
ss -ltnp 2>/dev/null | grep ':9097' || echo "WARN 9097 not listening"
echo "[DONE]"
