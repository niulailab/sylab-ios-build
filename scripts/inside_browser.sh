#!/bin/bash
echo "=== file inside container vs host ==="
docker exec browser-service sh -c 'md5sum /app/browser_service.py; wc -l /app/browser_service.py'
md5sum /root/coze-studio/browser-service/browser_service.py

echo ""
echo "=== grep return branches INSIDE container ==="
docker exec browser-service sh -c "grep -n 'screenshot_base64\|screenshot_error\|reachable' /app/browser_service.py | head -30"

echo ""
echo "=== mem/disk ==="
docker stats browser-service --no-stream --format 'cpu={{.CPUPerc}} mem={{.MemUsage}}'
df -h / | tail -1

echo ""
echo "=== run a real screenshot inside container via python ==="
docker exec browser-service python3 - <<'PY'
import asyncio, base64
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
        print("ERR",repr(e))
    finally:
        await b.close(); await pw.stop()
asyncio.run(main())
PY
echo "[DONE]"
