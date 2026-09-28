F="/root/coze-studio/tool-proxy/server.py"
s=open(F,encoding="utf-8").read()

old='''        async def _watch():
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
'''
new='''        exhausted = False
        async def _watch():
            nonlocal acc, pending, vis, have_vis, start_ts, detected, passed, exhausted
            async for chunk in resp.aiter_raw():
                acc += chunk
                pending += chunk
                evs, pending = _parse_sse_events(pending)
                tool_only = False
                ended = False
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
                    if (delta.get("tool_calls")):
                        tool_only = True
                    fr = ch0.get("finish_reason")
                    if fr:
                        ended = True
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
                else:
                    # no visible content yet: if the model is only emitting tool calls
                    # or this SSE event ended, the stream is safe -> replay buffer only.
                    if tool_only or ended:
                        exhausted = True
                        return
            exhausted = True

        await _watch()
'''
assert old in s, "watch block not found"
s=s.replace(old,new,1)

old2='''        if detected:
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
'''
new2='''        resp_headers = {}
        for k, v in resp.headers.items():
            if k.lower() in ("transfer-encoding", "connection", "content-length"):
                continue
            resp_headers[k] = v
        from fastapi.responses import StreamingResponse as _SR

        if detected:
            await _close(client, resp)
            rp = dict(orig_payload)
            rp["reasoning_effort"] = "low"
            for _k in ("thinking", "thinking_type", "enable_thinking", "thinking_budget"):
                rp.pop(_k, None)
            logging.warning("[zhipu-proxy] stream refusal detected in opening -> replay low")
            client2, resp2 = await _send(json.dumps(rp, ensure_ascii=False).encode("utf-8"))
            async def _iter_replay():
                try:
                    async for chunk in resp2.aiter_raw():
                        yield chunk
                finally:
                    await _close(client2, resp2)
            return _SR(content=_iter_replay(), status_code=resp2.status_code,
                       headers=resp_headers, media_type="text/event-stream")

        if exhausted:
            # stream fully (or up to a tool-only/end event) consumed during inspection:
            # return exactly what was buffered, do not re-read the consumed stream.
            _cap = client
            _r = resp
            async def _iter_bufonly():
                try:
                    yield acc
                finally:
                    await _close(_cap, _r)
            return _SR(content=_iter_bufonly(), status_code=resp.status_code,
                       headers=resp_headers, media_type=resp.headers.get("content-type", "text/event-stream"))

        buffered = acc  # safe opening, replay it then continue live tail
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
'''
assert old2 in s, "tail block not found"
s=s.replace(old2,new2,1)
open(F,"w",encoding="utf-8").write(s)
print("fixed")
