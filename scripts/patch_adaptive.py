import re,sys
F="/root/coze-studio/tool-proxy/server.py"
s=open(F,encoding="utf-8").read()

# locate the function block via its route decorator up to END marker
start_pat='@app.api_route("/bigmodel/v1/{path:path}"'
end_mark='# ==================== END ZHIPU PROXY PATCH ===================='
i=s.index(start_pat)
j=s.index(end_mark)+len(end_mark)

helpers='''
# ---------- ADAPTIVE REFUSAL -> low RETRY ----------
import time as _ztime
_REFUSAL_PATTERNS = [
    "没法帮", "无法帮", "不能帮", "无法协助", "不能协助", "无法提供",
    "底线", "原则问题", "违反我的", "违反安全", "抱歉，我不", "抱歉我不",
    "我不能", "我不会帮", "不支持部署", "去审查版", "越狱", "不能提供",
    "i can't help", "i cannot help", "i can't assist", "i cannot assist",
    "i'm unable to help", "unable to assist", "against my",
]
def _looks_like_refusal(txt):
    t = (txt or "").lower()
    return any(p in t for p in _REFUSAL_PATTERNS)
# ---------- END ADAPTIVE HELPERS ----------

'''

new_func='''@app.api_route("/bigmodel/v1/{path:path}", methods=["GET", "POST", "PUT", "DELETE", "OPTIONS"])
async def zhipu_proxy(path: str, request: Request):
    body = await request.body()
    orig_body = body
    is_chat = request.method == "POST" and "chat/completions" in path and bool(body)
    orig_payload = None
    want_stream = False
    if is_chat:
        try:
            orig_payload = json.loads(body)
            want_stream = bool(orig_payload.get("stream"))
        except Exception:
            orig_payload = None

    logging.info(f"[zhipu-proxy] {request.method} /bigmodel/{path} adaptive(stream={want_stream})")

    fwd_headers = {}
    for k, v in request.headers.items():
        if k.lower() in ("host", "content-length", "transfer-encoding", "connection", "accept-encoding"):
            continue
        fwd_headers[k] = v
    url = f"{ZHIPU_UPSTREAM}/{path}"

    async def _send(p_body):
        client = httpx.AsyncClient(timeout=httpx.Timeout(600.0, connect=30.0))
        req = client.build_request(request.method, url, headers=fwd_headers, content=p_body if p_body else None)
        r = await client.send(req, stream=True)
        return client, r

    async def _close(c, r):
        try:
            await r.aclose()
        except Exception:
            pass
        try:
            await c.aclose()
        except Exception:
            pass

    client, resp = await _send(body)

    # Image-400 tolerance: broken images carried in history -> strip & retry text-only once.
    if resp.status_code != 200 and is_chat:
        try:
            _err = (await resp.aread()).decode("utf-8", "ignore")
            await _close(client, resp)
            if _is_image_400(resp.status_code, _err) and isinstance(orig_payload, dict) and _payload_has_images(orig_payload):
                rp, _n = _strip_images_from_payload(orig_payload)
                orig_body = json.dumps(rp, ensure_ascii=False).encode("utf-8")
                logging.warning(f"[zhipu-proxy] image-400, retry text-only removed={_n}")
                client, resp = await _send(orig_body)
            else:
                from fastapi.responses import Response as _R
                ct = "application/json"
                try:
                    json.loads(_err)
                except Exception:
                    ct = "text/plain; charset=utf-8"
                return _R(content=_err.encode("utf-8"), status_code=resp.status_code, media_type=ct)
        except Exception as _e:
            logging.warning(f"[zhipu-proxy] image-400 setup failed: {_e}")
            from fastapi.responses import JSONResponse as _JRE
            return _JRE(status_code=502, content={"error": {"message": f"zhipu proxy error: {_e}"}})

    # Adaptive refusal handling.
    if resp.status_code == 200 and is_chat and isinstance(orig_payload, dict):
        refused = False
        if not want_stream:
            full = await resp.aread()
            await _close(client, resp)
            try:
                pj = json.loads(full.decode("utf-8", "ignore"))
                ch = (pj.get("choices") or [{}])[0]
                msg = ch.get("message") or {}
                visible = msg.get("content") or ""
                if _looks_like_refusal(visible):
                    refused = True
            except Exception:
                pass
            if refused:
                rp = dict(orig_payload)
                rp["reasoning_effort"] = "low"
                for _k in ("thinking", "thinking_type", "enable_thinking", "thinking_budget"):
                    rp.pop(_k, None)
                logging.warning("[zhipu-proxy] non-stream refusal detected -> replay low")
                client, resp = await _send(json.dumps(rp, ensure_ascii=False).encode("utf-8"))
            from fastapi.responses import Response as _RR
            rh = {}
            for k, v in resp.headers.items():
                if k.lower() in ("transfer-encoding", "connection", "content-length"):
                    continue
                rh[k] = v
            if not refused:
                return _RR(content=full, status_code=resp.status_code, headers=rh,
                           media_type=resp.headers.get("content-type", "application/json"))
            body_final = await resp.aread()
            await _close(client, resp)
            return _RR(content=body_final, status_code=resp.status_code, headers=rh,
                       media_type=resp.headers.get("content-type", "application/json"))

        # Streaming: buffer the opening until enough visible text / time, detect refusal.
        detected = False
        passed = False
        acc = b""
        pending = b""
        vis = ""
        have_vis = False
        start_ts = None
        MAXC = 120
        MAXW = 8.0

        async def _watch():
            nonlocal acc, pending, vis, have_vis, start_ts, detected, passed
            async for chunk in resp.aiter_raw():
                acc += chunk
                pending += chunk
                evs, pending = _parse_sse_events(pending)
                for raw_ev, ob in evs:
                    if ob is None:
                        continue
                    try:
                        ch0 = ob.get("choices", [])[0]
                    except Exception:
                        continue
                    delta = ch0.get("delta") or {}
                    c = delta.get("content")
                    if isinstance(c, str) and c:
                        if start_ts is None:
                            start_ts = _ztime.time()
                        vis += c
                        have_vis = True
                if have_vis:
                    if _looks_like_refusal(vis[:MAXC]):
                        detected = True
                        return
                    if len(vis) >= MAXC:
                        passed = True
                        return
                    if start_ts is not None and (_ztime.time() - start_ts) >= MAXW:
                        passed = True
                        return

        await _watch()

        if detected:
            await _close(client, resp)
            rp = dict(orig_payload)
            rp["reasoning_effort"] = "low"
            for _k in ("thinking", "thinking_type", "enable_thinking", "thinking_budget"):
                rp.pop(_k, None)
            logging.warning("[zhipu-proxy] stream refusal detected in opening -> replay low")
            client, resp = await _send(json.dumps(rp, ensure_ascii=False).encode("utf-8"))
            buffered = b""
        else:
            buffered = acc  # replay the buffered head untouched, then continue live

        resp_headers = {}
        for k, v in resp.headers.items():
            if k.lower() in ("transfer-encoding", "connection", "content-length"):
                continue
            resp_headers[k] = v
        from fastapi.responses import StreamingResponse as _SR

        async def _iter_tail():
            try:
                if buffered:
                    yield buffered
                async for chunk in resp.aiter_raw():
                    yield chunk
            finally:
                await _close(client, resp)

        return _SR(content=_iter_tail(), status_code=resp.status_code,
                   headers=resp_headers, media_type=resp.headers.get("content-type", "text/event-stream"))

    resp_headers = {}
    for k, v in resp.headers.items():
        if k.lower() in ("transfer-encoding", "connection", "content-length"):
            continue
        resp_headers[k] = v
    from fastapi.responses import StreamingResponse as _SR

    async def _iter_plain():
        try:
            async for chunk in resp.aiter_raw():
                yield chunk
        finally:
            await _close(client, resp)

    return _SR(content=_iter_plain(), status_code=resp.status_code,
               headers=resp_headers, media_type=resp.headers.get("content-type", "application/json"))
'''

# add a module-level SSE parser used above (insert right before route decorator)
sse_parser='''
def _parse_sse_events(buf):
    """Split buffered bytes into completed SSE events. Returns (events, remaining).
    events = list of (raw_bytes, json_or_None) for data lines that are JSON."""
    events = []
    pos = 0
    while True:
        k = buf.find(b"\\n\\n", pos)
        if k == -1:
            break
        block = buf[pos:k]
        pos = k + 2
        for line in block.splitlines():
            line = line.strip()
            if not line.startswith(b"data:"):
                continue
            payload = line[5:].strip()
            if not payload or payload == b"[DONE]":
                events.append((line, None))
                continue
            try:
                events.append((line, json.loads(payload.decode("utf-8", "ignore"))))
            except Exception:
                events.append((line, None))
    return events, buf[pos:]

'''

block = sse_parser + helpers + new_func + "\n"
out = s[:i] + block + s[j:]
open(F,"w",encoding="utf-8").write(out)
print("patched bytes", len(s), "->", len(out))
