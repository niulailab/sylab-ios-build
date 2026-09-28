#!/bin/bash
# BUG1 自愈补丁：browser-service 截图失败/空图 -> 强制重建单例会话并重试一次
set -e
F=/root/coze-studio/browser-service/browser_service.py
TS=$(date +%Y%m%d_%H%M%S)
cp "$F" "${F}.bak_selfheal_${TS}"
echo "backup -> ${F}.bak_selfheal_${TS}"

python3 - "$F" <<'PY'
import sys
f=sys.argv[1]
s=open(f,encoding="utf-8").read()

# 1) 在 _get_agent_page 之后插入 _reset_agent_session 工具函数
anchor='''async def _visible_clickables(page, limit=30):'''
assert s.count(anchor)==1, "anchor _visible_clickables not unique/found"

helper='''async def _reset_agent_session():
    """强制销毁并清理持久 agent page/context/browser/playwright，下次调用时全新重建。
    用于网络抖动/TLS 故障后单例 page 进入坏状态（看着 connected 但外网页打不开/截图为空）。"""
    global agent_context, agent_page, browser, playwright_instance
    for obj, name in ((agent_context, "context"), (browser, "browser")):
        try:
            if obj is not None:
                await obj.close()
        except Exception:
            pass
    try:
        if playwright_instance is not None:
            await playwright_instance.stop()
    except Exception:
        pass
    agent_context = None
    agent_page = None
    browser = None
    playwright_instance = None
    print("[browser] agent session force-reset (self-heal)")


'''
s=s.replace(anchor, helper+anchor, 1)

# 2) 重写 take_screenshot：抽内部 _attempt，外层在坏结果时 reset + 重试一次
old_start='''@app.post("/browser/screenshot")
async def take_screenshot(request: Dict[str, Any]):
    url = request.get("url")
    full_page = request.get("full_page", False)
    width = request.get("width", 390)
    height = request.get("height", 844)
    if not url:
        raise HTTPException(400, "url is required")
    lock = None
    try:
        page, lock = await _get_agent_page(None)
        nav_ok = False
        nav_err = ""
        try:
            await page.goto(url, wait_until="commit", timeout=12000)
            nav_ok = True
        except Exception as _ge:
            nav_err = str(_ge)
            _low = nav_err.lower()
            _fatal = ("timeout" in _low or "network is unreachable" in _low
                      or "err_" in _low or "net::" in _low or "connection" in _low)
            if not _fatal:
                try:
                    await page.goto(url, wait_until="domcontentloaded", timeout=12000)
                    nav_ok = True; nav_err = ""
                except Exception as _ge2:
                    nav_err = str(_ge2) or nav_err
        if not nav_ok:
            hint = ("[截图失败] 该 URL 当前无法从服务器访问（连接超时、被网络阻断或站点无响应）。"
                    "请不要再截图同一 URL，可改用 web_search 或基于已有信息回答，并简短告知用户该网页暂时打不开。"
                    "原始错误：" + nav_err[:140])
            return {"code": 0, "msg": "success",
                    "data": {"screenshot_error": hint, "url": url, "reachable": False}}
        try:
            await page.wait_for_load_state("networkidle", timeout=6000)
        except Exception:
            pass
        try:
            screenshot_bytes = await page.screenshot(full_page=full_page, type="png")
        except Exception as _se:
            hint = ("[截图失败] 页面已连接但渲染截图异常（" + str(_se)[:120] +
                    "）。请改用 get_content/web_search 或基于已有信息回答，不要重试同一 URL。")
            return {"code": 0, "msg": "success",
                    "data": {"screenshot_error": hint, "url": url, "reachable": True}}
        cur_url = page.url
        return {
            "code": 0, "msg": "success",
            "data": {
                "screenshot_base64": base64.b64encode(screenshot_bytes).decode(),
                "format": "png", "size_bytes": len(screenshot_bytes),
                "url": cur_url, "reachable": True,
                "viewport": {"width": width, "height": height}
            }
        }
    except Exception as e:
        hint = ("[截图失败] 浏览器服务临时异常（" + str(e)[:120] +
                "）。请改用 web_search 或基于已有信息回答，不要重试同一 URL。")
        return {"code": 0, "msg": "success",
                "data": {"screenshot_error": hint, "url": url or "", "reachable": False}}
    finally:
        if lock is not None:
            try:
                lock.release()
            except Exception:
                pass'''

new='''@app.post("/browser/screenshot")
async def take_screenshot(request: Dict[str, Any]):
    url = request.get("url")
    full_page = request.get("full_page", False)
    width = request.get("width", 390)
    height = request.get("height", 844)
    if not url:
        raise HTTPException(400, "url is required")

    async def _attempt():
        """单次截图尝试。返回 (data_dict, healthy)；healthy=False 表示疑似单例坏态，可重建重试。"""
        lock = None
        try:
            page, lock = await _get_agent_page(None)
            nav_ok = False
            nav_err = ""
            try:
                await page.goto(url, wait_until="commit", timeout=12000)
                nav_ok = True
            except Exception as _ge:
                nav_err = str(_ge)
                _low = nav_err.lower()
                _fatal = ("timeout" in _low or "network is unreachable" in _low
                          or "err_" in _low or "net::" in _low or "connection" in _low)
                if not _fatal:
                    try:
                        await page.goto(url, wait_until="domcontentloaded", timeout=12000)
                        nav_ok = True; nav_err = ""
                    except Exception as _ge2:
                        nav_err = str(_ge2) or nav_err
            if not nav_ok:
                hint = ("[截图失败] 该 URL 当前无法从服务器访问（连接超时、被网络阻断或站点无响应）。"
                        "请不要再截图同一 URL，可改用 web_search 或基于已有信息回答，并简短告知用户该网页暂时打不开。"
                        "原始错误：" + nav_err[:140])
                return ({"screenshot_error": hint, "url": url, "reachable": False}, False)
            try:
                await page.wait_for_load_state("networkidle", timeout=6000)
            except Exception:
                pass
            try:
                screenshot_bytes = await page.screenshot(full_page=full_page, type="png")
            except Exception as _se:
                hint = ("[截图失败] 页面已连接但渲染截图异常（" + str(_se)[:120] +
                        "）。请改用 get_content/web_search 或基于已有信息回答，不要重试同一 URL。")
                return ({"screenshot_error": hint, "url": url, "reachable": True}, False)
            if not screenshot_bytes:
                return ({"screenshot_error": "[截图失败] 截图返回为空。", "url": url, "reachable": True}, False)
            cur_url = page.url
            return ({
                "screenshot_base64": base64.b64encode(screenshot_bytes).decode(),
                "format": "png", "size_bytes": len(screenshot_bytes),
                "url": cur_url, "reachable": True,
                "viewport": {"width": width, "height": height}
            }, True)
        except Exception as e:
            hint = ("[截图失败] 浏览器服务临时异常（" + str(e)[:120] +
                    "）。请改用 web_search 或基于已有信息回答，不要重试同一 URL。")
            return ({"screenshot_error": hint, "url": url or "", "reachable": False}, False)
        finally:
            if lock is not None:
                try:
                    lock.release()
                except Exception:
                    pass

    data, healthy = await _attempt()
    # 自愈：结果异常/空图（疑似持久单例坏态）时，强制重建会话再试一次
    if not healthy or not data.get("screenshot_base64"):
        try:
            await _reset_agent_session()
        except Exception:
            pass
        data, _ = await _attempt()
    return {"code": 0, "msg": "success", "data": data}'''

assert s.count(old_start)==1, "take_screenshot block not unique/found"
s=s.replace(old_start,new,1)

open(f,"w",encoding="utf-8").write(s)
print("patched OK")
PY

python3 -m py_compile "$F" && echo "py_compile OK"
docker restart browser-service
sleep 12
docker exec browser-service sh -c 'grep -c "_reset_agent_session" /app/browser_service.py'
echo "[DONE]"
