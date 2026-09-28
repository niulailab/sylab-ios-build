#!/bin/bash
cat > /tmp/_nt.py <<'PY'
import socket, urllib.request, sys, asyncio
from playwright.async_api import async_playwright
def t(name, fam):
    try:
        infos=socket.getaddrinfo("example.com",443,fam,socket.SOCK_STREAM)
        ip=infos[0][4][0]
        s=socket.socket(fam,socket.SOCK_STREAM); s.settimeout(8)
        s.connect((ip,443)); print(name,"OK",ip); s.close()
    except Exception as e:
        print(name,"ERR",repr(e)[:160])
t("v4",socket.AF_INET)
t("v6",socket.AF_INET6)
try:
    r=urllib.request.urlopen("https://example.com",timeout=10)
    print("urllib default",r.status)
except Exception as e:
    print("urllib ERR",repr(e)[:200])
sys.stdout.flush()
async def ms():
    pw=await async_playwright().start()
    b=await pw.chromium.launch(args=["--no-sandbox"])
    p=await b.new_page()
    try:
        await p.goto("http://example.com", timeout=15000)
        img=await p.screenshot()
        print("SHOT http bytes",len(img))
    except Exception as e:
        print("SHOT ERR",repr(e)[:300])
    finally:
        await b.close(); await pw.stop()
asyncio.run(ms())
print("ALLDONE"); sys.stdout.flush()
PY
docker cp /tmp/_nt.py browser-service:/tmp/_nt.py
docker exec browser-service python3 -u /tmp/_nt.py 2>&1
echo "[DONE]"
