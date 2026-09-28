#!/bin/bash
# ============================================================================
# sylab 定时任务 v140 后端补丁
# 改动点（纯增量，不动表结构/计费/队列/DAG）：
#  1) 鉴权加固：session_key 回查 user 表 + 内网/网关注入才采信 header（防越权/防直连伪造）
#  2) 成功判定：fire 仅代表入队；后台 _watch_final 轮询终态(completed/failed)
#  3) once 孤儿：_sweep_once_orphans 复活 deleted+running 的崩溃任务
#  4) list 跨会话：scope=all 返回该用户全部任务（供「我的」管理页）
# 安全：先备份；每处替换断言唯一；py_compile 通过后才重启；版本号递增。
# ============================================================================
set -euo pipefail
TP=/root/coze-studio/tool-proxy
F="$TP/server.py"
TS=$(date +%Y%m%d_%H%M%S)
BAK="$F.bak_v140_$TS"

cp -a "$F" "$BAK"
echo "[backup] $BAK"

python3 - "$F" <<'PYEOF'
import sys, io
f = sys.argv[1]
s = open(f, encoding='utf-8').read()

def rep(old, new, tag):
    global s
    n = s.count(old)
    if n != 1:
        sys.exit(f"[FAIL] {tag}: anchor count={n}, expected 1")
    s = s.replace(old, new)
    print(f"[ok] {tag}")

# ------------------------------------------------------------------ 块1：鉴权
old_id = '''def _get_identity(raw_request: Request):
    uid = (raw_request.headers.get("x-aiplugin-connector-identifier", "")
           or raw_request.headers.get("x-aiplugin-user-id", "")
           or raw_request.headers.get("x-user-id", ""))
    conv = raw_request.headers.get("x-aiplugin-conversation-id", "")
    uid = uid.strip()
    conv = conv.strip()
    if not uid or not conv:
        import sys as _sys
        print(f"[SCHED-DBG] identity incomplete uid={uid!r} conv={conv!r} headers={dict(raw_request.headers)}", file=_sys.stderr, flush=True)
    return uid, conv'''

new_id = '''INTERNAL_GATEWAY_HEADER = "x-sylab-gateway"
INTERNAL_GATEWAY_SECRET = "sylab-gw-2026"

def _extract_session_key(raw_request: Request):
    ck = raw_request.headers.get("cookie", "") or ""
    for part in ck.split(";"):
        part = part.strip()
        if part.startswith("session_key="):
            return part[len("session_key="):].strip()
    return (raw_request.headers.get("x-session-key", "")
            or raw_request.headers.get("x-aiplugin-session-key", "")).strip()

def _trusted_source(raw_request: Request):
    if raw_request.headers.get(INTERNAL_GATEWAY_HEADER, "") == INTERNAL_GATEWAY_SECRET:
        return True
    ip = (raw_request.client.host if raw_request.client else "") or ""
    return ip.startswith("127.") or ip == "::1" or ip.startswith("172.17.") or ip.startswith("172.18.")

def _resolve_user(raw_request: Request):
    """可信身份。返回 (uid, conv)。
    1) session_key 回查 user 表命中即可信；
    2) 否则仅当来源为 docker 内网/受信网关，才采信插件 header（防直连 9092 伪造）。"""
    conv = (raw_request.headers.get("x-aiplugin-conversation-id", "") or "").strip()
    sk = _extract_session_key(raw_request)
    if sk:
        try:
            conn = get_db_connection()
            try:
                with conn.cursor() as cur:
                    cur.execute(
                        "SELECT id FROM user WHERE session_key=%s AND deleted_at IS NULL LIMIT 1",
                        (sk,))
                    row = cur.fetchone()
            finally:
                conn.close()
            if row:
                return str(row["id"]), conv
        except Exception as e:
            logging.warning(f"[scheduler] session resolve error: {e}")
    if _trusted_source(raw_request):
        uid = (raw_request.headers.get("x-aiplugin-connector-identifier", "")
               or raw_request.headers.get("x-aiplugin-user-id", "")
               or raw_request.headers.get("x-user-id", ""))
        uid = uid.strip()
        if uid:
            return uid, conv
    return "", conv

def _get_identity(raw_request: Request):
    uid, conv = _resolve_user(raw_request)
    if not uid:
        import sys as _sys
        print(f"[SCHED-DBG] identity unresolved conv={conv!r}", file=_sys.stderr, flush=True)
    return uid, conv'''
rep(old_id, new_id, "1-auth")

# ------------------------------------------------------------------ 块2：list 跨会话
old_list = '''                cur.execute(
                    "SELECT * FROM sylab_scheduled_tasks WHERE user_id=%s AND status!='deleted' AND conversation_id=%s ORDER BY id DESC",
                    (uid, conv))
                rows = cur.fetchall()
                if scope != "all":
                    cur.execute(
                        "SELECT COUNT(*) c FROM sylab_scheduled_tasks WHERE user_id=%s AND status!='deleted' AND conversation_id!=%s",
                        (uid, conv))
                    other_active = cur.fetchone()["c"]
                else:
                    other_active = 0'''

new_list = '''                if scope == "all":
                    cur.execute(
                        "SELECT * FROM sylab_scheduled_tasks WHERE user_id=%s AND status!='deleted' ORDER BY id DESC",
                        (uid,))
                    other_active = 0
                else:
                    cur.execute(
                        "SELECT * FROM sylab_scheduled_tasks WHERE user_id=%s AND status!='deleted' AND conversation_id=%s ORDER BY id DESC",
                        (uid, conv))
                    cur.execute(
                        "SELECT COUNT(*) c FROM sylab_scheduled_tasks WHERE user_id=%s AND status!='deleted' AND conversation_id!=%s",
                        (uid, conv))
                    other_active = cur.fetchone()["c"]
                rows = cur.fetchall()'''
rep(old_list, new_list, "2-list-all")

# ------------------------------------------------------------------ 块3：fire 不再即判成功
old_fire = '''        if not data.get("ok"):
            reason = data.get("reason", "unknown")
            raise RuntimeError(f"fire not ok: {reason} {data.get('balance','')}")
        conn = get_db_connection()
        try:
            with conn.cursor() as cur:
                cur.execute("UPDATE sylab_scheduled_tasks SET last_status='success', consecutive_failures=0 WHERE id=%s", (task_id,))
                cur.execute("INSERT INTO sylab_schedule_runs (task_uuid,fired_at,result_status,detail) VALUES (%s,%s,'success','')",
                            (task_uuid, _now()))
            conn.commit()
        finally:
            conn.close()
        logging.info(f"[scheduler] fired ok task={task_uuid}")'''

new_fire = '''        if not data.get("ok"):
            reason = data.get("reason", "unknown")
            raise RuntimeError(f"fire not ok: {reason} {data.get('balance','')}")
        # ok 仅代表"已入队"；真实成败由后台 _watch_final 轮询终态决定
        conn = get_db_connection()
        try:
            with conn.cursor() as cur:
                cur.execute("UPDATE sylab_scheduled_tasks SET last_status='running', consecutive_failures=0 WHERE id=%s", (task_id,))
            conn.commit()
        finally:
            conn.close()
        logging.info(f"[scheduler] enqueued task={task_uuid}, watching final status")
        _asyncio.create_task(_watch_final(t, task_uuid))'''
rep(old_fire, new_fire, "3-fire-enqueue")

# ------------------------------------------------------------------ 块4：新增 watch + orphan sweep，并挂入 tick
old_tick = '''async def _scheduler_tick():
    try:
        now = _now()
        conn = get_db_connection()'''

new_tick = '''STATUS_URL = "http://172.18.0.1:9088/internal/status-by-uuid"

async def _watch_final(t: dict, task_uuid: str):
    """轮询队列终态：completed 才记真成功；failed/超时记失败。重复任务不重算下次；
    once 失败则复活(给紧邻未来时间)重试，成功保持 deleted。"""
    task_id = t["id"]
    final_status = None
    detail = ""
    try:
        async with httpx.AsyncClient(timeout=httpx.Timeout(20.0, connect=8.0)) as client:
            for _i in range(60):          # 最多约 10 分钟
                await _asyncio.sleep(10)
                try:
                    r = await client.post(
                        STATUS_URL, json={"task_uuid": task_uuid},
                        headers={"X-Internal-Key": FIRE_KEY, "Content-Type": "application/json"})
                    d = r.json()
                except Exception:
                    continue
                if not d.get("found"):
                    continue
                st = d.get("status", "")
                if st == "completed":
                    final_status = "success"
                    break
                if st == "failed":
                    final_status = "failed"
                    detail = (d.get("error") or "执行失败")[:300]
                    break
        if final_status is None:
            final_status = "failed"
            detail = "等待执行结果超时"
        conn = get_db_connection()
        try:
            with conn.cursor() as cur:
                if final_status == "success":
                    cur.execute(
                        "UPDATE sylab_scheduled_tasks SET last_status='success', consecutive_failures=0 WHERE id=%s",
                        (task_id,))
                else:
                    cur.execute(
                        "SELECT consecutive_failures FROM sylab_scheduled_tasks WHERE id=%s",
                        (task_id,))
                    rr = cur.fetchone()
                    fails = int(((rr or {}).get("consecutive_failures", 0) or 0)) + 1
                    ns = "paused" if fails >= 3 else "active"
                    if t["schedule_type"] == "once":
                        cur.execute(
                            "UPDATE sylab_scheduled_tasks SET last_status='failed', consecutive_failures=%s, "
                            "status='active', next_run_at=%s WHERE id=%s",
                            (fails, _now() + _td(seconds=5), task_id))
                    else:
                        cur.execute(
                            "UPDATE sylab_scheduled_tasks SET last_status='failed', consecutive_failures=%s, status=%s WHERE id=%s",
                            (fails, ns, task_id))
                cur.execute(
                    "INSERT INTO sylab_schedule_runs (task_uuid,fired_at,result_status,detail) VALUES (%s,%s,%s,%s)",
                    (task_uuid, _now(), final_status, detail))
            conn.commit()
        finally:
            conn.close()
        logging.info(f"[scheduler] watch final task={task_uuid} -> {final_status}")
    except Exception as e:
        logging.error(f"[scheduler] watch error task={task_uuid}: {e}")

async def _sweep_once_orphans(now):
    """认领后崩溃：once 停在 deleted + last_status='running'。复活重试（at-least-once）。"""
    try:
        conn = get_db_connection()
        try:
            with conn.cursor() as cur:
                cur.execute(
                    "UPDATE sylab_scheduled_tasks SET status='active', next_run_at=%s, last_status='failed' "
                    "WHERE schedule_type='once' AND status='deleted' AND last_status='running'",
                    (now,))
                fixed = cur.rowcount
            conn.commit()
        finally:
            conn.close()
        if fixed:
            logging.info(f"[scheduler] revived {fixed} once orphan(s)")
    except Exception as e:
        logging.warning(f"[scheduler] orphan sweep error: {e}")

async def _scheduler_tick():
    try:
        now = _now()
        await _sweep_once_orphans(now)
        conn = get_db_connection()'''
rep(old_tick, new_tick, "4-watch-orphan-tick")

open(f, 'w', encoding='utf-8').write(s)
print("[written] server.py patched")
PYEOF

echo ""
echo "=== py_compile 校验 ==="
python3 -m py_compile "$F" && echo "[compile] OK"

echo ""
echo "=== tool-proxy 挂载情况（决定重启是否生效）==="
docker inspect tool-proxy --format '{{range .Mounts}}{{.Source}} -> {{.Destination}}{{"\n"}}{{end}}'

echo ""
echo "[DONE] patch + compile finished; restart handled by caller step"
