# -*- coding: utf-8 -*-
import sys, py_compile
P="/root/coze-studio/tool-proxy/server.py"
s=open(P,encoding="utf-8").read()
orig=s
edits=[]

# --- Edit A: 插入 /browser/content 转发 ---
anchor="# ==================== 静态网页发布 ===================="
block='''# ==================== 网页正文抓取 ====================
@app.post("/browser/content")
async def browser_content(request: dict):
    """Fetch page readable text via browser-service (proxy)."""
    url = request.get("url", "")
    if not url:
        raise HTTPException(400, "url is required")
    try:
        async with httpx.AsyncClient(timeout=60) as client:
            resp = await client.post("http://browser-service:9096/browser/content",
                                     json={"url": url})
        if resp.status_code != 200:
            raise HTTPException(502, f"browser-service error: {resp.status_code}")
        j = resp.json()
        text = (j.get("data") or {}).get("text", "")
        if not text:
            return {"code": 1, "msg": "empty content",
                    "data": {"url": url, "text": "", "anti_bot_detected": True}}
        return {"code": 0, "msg": "success",
                "data": {"url": url, "text": text}}
    except httpx.ConnectError:
        raise HTTPException(503, "Browser service not available")
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(500, f"Error: {str(e)}")


'''
if "@app.post(\"/browser/content\")" in s:
    edits.append("A:skip(exists)")
elif anchor in s:
    s=s.replace(anchor, block+anchor, 1); edits.append("A:ok")
else:
    print("FATAL anchor A missing"); sys.exit(2)

# --- Edit B: web_search 带 bocha_error ---
old_b='''    if BOCHA_API_KEY:
        try:
            results = await _search_bocha(query, count, freshness)
            if results:
                return {"code": 0, "msg": "success",
                        "data": {"source": "bocha", "total": len(results), "results": results}}
        except Exception as e:
            print(f"[WEB_SEARCH] Bocha failed, falling back to 360: {e}")
    try:
        results = await _search_360(query, count)
        return {"code": 0, "msg": "success",
                "data": {"source": "360-fallback", "total": len(results), "results": results}}
    except Exception as e:
        raise HTTPException(500, f"Search error: {str(e)}")'''
new_b='''    bocha_error = None
    if BOCHA_API_KEY:
        try:
            results = await _search_bocha(query, count, freshness)
            if results:
                return {"code": 0, "msg": "success",
                        "data": {"source": "bocha", "total": len(results), "results": results}}
            bocha_error = "bocha returned empty result set"
        except Exception as e:
            bocha_error = str(e)
            print(f"[WEB_SEARCH] Bocha failed, falling back to 360: {e}")
    else:
        bocha_error = "BOCHA_API_KEY not configured in tool-proxy env"
    try:
        results = await _search_360(query, count)
        return {"code": 0, "msg": "success",
                "data": {"source": "360-fallback", "total": len(results),
                         "bocha_error": bocha_error, "results": results}}
    except Exception as e:
        raise HTTPException(500, f"Search error: {str(e)} (bocha_error={bocha_error})")'''
if '"bocha_error": bocha_error' in s:
    edits.append("B:skip(exists)")
elif old_b in s:
    s=s.replace(old_b,new_b,1); edits.append("B:ok")
else:
    print("FATAL anchor B missing"); sys.exit(3)

# --- Edit C: 截图加一次自动重试 ---
old_c='''        async with httpx.AsyncClient(timeout=60) as client:
            resp = await client.post("http://browser-service:9096/browser/screenshot", json={"url": url, "full_page": False})
            if resp.status_code == 200:'''
new_c='''        async with httpx.AsyncClient(timeout=60) as client:
            resp = None
            for _shot_attempt in range(2):
                resp = await client.post("http://browser-service:9096/browser/screenshot", json={"url": url, "full_page": False})
                try:
                    _ok_shot = resp.status_code == 200 and resp.json().get("data", {}).get("screenshot_base64")
                except Exception:
                    _ok_shot = False
                if _ok_shot:
                    break
            if resp.status_code == 200:'''
if "for _shot_attempt in range(2)" in s:
    edits.append("C:skip(exists)")
elif old_c in s:
    s=s.replace(old_c,new_c,1); edits.append("C:ok")
else:
    print("FATAL anchor C missing"); sys.exit(4)

if s==orig:
    print("no changes (all already applied?)")
py_compile.compile(P, doraise=True)  # backup not needed; compile check before write
open(P,"w",encoding="utf-8").write(s)
py_compile.compile(P, doraise=True)
print("EDITS:",edits)
print("server.py patched & syntax OK, bytes=",len(s.encode()))
