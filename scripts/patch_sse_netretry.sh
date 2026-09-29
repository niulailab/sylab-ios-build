#!/bin/bash
set -euo pipefail
cd /root/coze-studio/tool-proxy
F=server.py
TS=$(date +%Y%m%d_%H%M%S)
cp -p "$F" "${F}.bak_ssere_${TS}"
echo "[1] backed up ${F}.bak_ssere_${TS}"

python3 - <<'PY'
import pathlib
p = pathlib.Path("server.py")
src = p.read_text()

OLD_ITER = '''    async def _iter():
        _buf=b""
        try:
            async for chunk in resp.aiter_raw():
                _buf+=chunk
                yield chunk
        finally:
            try:
                txt=_buf.decode("utf-8","ignore").strip()
                def _emit(_p):
                    for _c in _p.get("choices",[]):
                        fr=_c.get("finish_reason")
                        msg=_c.get("message") or {}
                        tcs=msg.get("tool_calls") or []
                        info=[]
                        for t in tcs:
                            fn=t.get("function") or {}
                            aa=fn.get("arguments") or ""
                            info.append("%s(len=%d)"%(fn.get("name"),len(aa)))
                        logging.info("[zhipu-FINISH] reason=%s tools=[%s] usage=%s",
                                     fr, ",".join(info), _p.get("usage"))
                if txt.startswith("{") and "finish_reason" in txt:
                    _emit(json.loads(txt))
                else:
                    for _ln in txt.splitlines():
                        if _ln.startswith("data:") and "finish_reason" in _ln:
                            _v=_ln[5:].strip()
                            if _v and _v!="[DONE]":
                                _emit(json.loads(_v))
            except Exception as _e:
                logging.info("[zhipu-FINISH] parse fail: %s", _e)
            await resp.aclose()
            await client.aclose()'''

NEW_ITER = '''    async def _iter():
        _buf=b""
        _network_errored = False
        try:
            async for chunk in resp.aiter_raw():
                _buf+=chunk
                yield chunk
        except Exception as _stream_err:
            logging.warning("[zhipu-proxy] SSE stream exception: %s", _stream_err)
            _network_errored = True
        finally:
            try:
                txt=_buf.decode("utf-8","ignore").strip()
                def _emit(_p):
                    for _c in _p.get("choices",[]):
                        fr=_c.get("finish_reason")
                        msg=_c.get("message") or {}
                        tcs=msg.get("tool_calls") or []
                        info=[]
                        for t in tcs:
                            fn=t.get("function") or {}
                            aa=fn.get("arguments") or ""
                            info.append("%s(len=%d)"%(fn.get("name"),len(aa)))
                        logging.info("[zhipu-FINISH] reason=%s tools=[%s] usage=%s",
                                     fr, ",".join(info), _p.get("usage"))
                if txt.startswith("{") and "finish_reason" in txt:
                    _emit(json.loads(txt))
                else:
                    for _ln in txt.splitlines():
                        if _ln.startswith("data:") and "finish_reason" in _ln:
                            _v=_ln[5:].strip()
                            if _v and _v!="[DONE]":
                                _emit(json.loads(_v))
            except Exception as _e:
                logging.info("[zhipu-FINISH] parse fail: %s", _e)
            await resp.aclose()
            await client.aclose()

        # ---------- 智谱网络错误自动重试（最多 1 次） ----------
        # 检测：finish_reason=network_error 或 usage=None 表示流中途被智谱掐断
        _needs_retry = _network_errored
        if not _needs_retry and txt:
            try:
                # 扫描 buffer 找 finish_reason 和 usage
                _has_network_err = False
                _has_usage = False
                for _ln2 in txt.splitlines():
                    if not _ln2.startswith("data:"): continue
                    _v2 = _ln2[5:].strip()
                    if not _v2 or _v2 == "[DONE]": continue
                    try:
                        _j2 = json.loads(_v2)
                    except Exception:
                        continue
                    for _c2 in _j2.get("choices", []):
                        if _c2.get("finish_reason") == "network_error":
                            _has_network_err = True
                    if _j2.get("usage") is not None:
                        _has_usage = True
                if _has_network_err and not _has_usage:
                    _needs_retry = True
                    logging.warning("[zhipu-proxy] detected finish_reason=network_error with usage=None, will retry once")
            except Exception as _scan_err:
                logging.warning("[zhipu-proxy] retry scan error: %s", _scan_err)

        if _needs_retry:
            logging.info("[zhipu-proxy] retrying upstream request after network_error")
            try:
                _client2 = httpx.AsyncClient(timeout=httpx.Timeout(600.0, connect=30.0))
                _req2 = _client2.build_request(request.method, url, headers=fwd_headers, content=body if body else None)
                _resp2 = await _client2.send(_req2, stream=True)
                logging.info("[zhipu-proxy] retry upstream responded with status=%s", _resp2.status_code)
                if _resp2.status_code == 200:
                    try:
                        async for chunk in _resp2.aiter_raw():
                            yield chunk
                    except Exception as _retry_stream_err:
                        logging.warning("[zhipu-proxy] retry stream exception: %s", _retry_stream_err)
                await _resp2.aclose()
                await _client2.aclose()
            except Exception as _retry_err:
                logging.warning("[zhipu-proxy] retry failed: %s", _retry_err)
        # ---------- END 智谱网络错误自动重试 ----------'''

assert OLD_ITER in src, "OLD_ITER anchor not found - code has changed"
src = src.replace(OLD_ITER, NEW_ITER)
p.write_text(src)
print("[2] patched _iter() with network_error auto-retry")
PY

# 3) py_compile
python3 -c "import py_compile; py_compile.compile('$F', doraise=True)" && echo "[3] py_compile OK"

# 4) restart tool-proxy
docker restart tool-proxy
sleep 8
docker ps --filter name=tool-proxy --format '{{.Names}}\t{{.Status}}'

# 5) verify patch in container
echo
echo "=== verify patch in container ==="
docker exec tool-proxy grep -c "retrying upstream request after network_error" /app/server.py
docker exec tool-proxy grep -c "detected finish_reason=network_error" /app/server.py

echo "[DONE]"
