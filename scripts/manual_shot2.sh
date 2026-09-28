#!/bin/bash
cat > /tmp/_ms2.py <<'PY'
import asyncio
from playwright.async_api import async_playwright
async def main():
    pw=await async_playwright().start()
    b=await pw.chromium.launch(args=["--no-sandbox"])
    p=await b.new_page()
    try:
        await p.goto("https://example.com", timeout=20000)
        print("GOTO OK")
    except Exception as e:
        print("GOTO ERR ->", repr(e)[:500])
    finally:
        await b.close(); await pw.stop()
asyncio.run(main())
PY
docker cp /tmp/_ms2.py browser-service:/tmp/_ms2.py
docker exec browser-service python3 /tmp/_ms2.py
echo "=== outbound DNS/net from container ==="
docker exec browser-service sh -c 'getent hosts example.com; cat /etc/resolv.conf'
echo "[DONE]"
