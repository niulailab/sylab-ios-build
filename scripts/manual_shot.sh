#!/bin/bash
cat > /tmp/_ms.py <<'PY'
import asyncio, base64, traceback
from playwright.async_api import async_playwright
async def main():
    pw=await async_playwright().start()
    b=await pw.chromium.launch(args=["--no-sandbox"])
    p=await b.new_page(viewport={"width":390,"height":844})
    try:
        await p.goto("https://example.com", wait_until="domcontentloaded", timeout=20000)
        await p.wait_for_timeout(800)
        img=await p.screenshot(type="png")
        print("OK bytes=",len(img),"b64len=",len(base64.b64encode(img).decode()))
    except Exception as e:
        print("ERR",repr(e)); traceback.print_exc()
    finally:
        await b.close(); await pw.stop()
asyncio.run(main())
PY
docker cp /tmp/_ms.py browser-service:/tmp/_ms.py
docker exec browser-service python3 /tmp/_ms.py
echo "[DONE]"
