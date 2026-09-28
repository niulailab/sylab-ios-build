#!/usr/bin/env python3
"""Fix: when tool_calls detected in stream with visible text, pass through immediately."""
import shutil, subprocess, datetime

SRC = "/root/coze-studio/tool-proxy/server.py"
ts = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
shutil.copy2(SRC, f"/root/backups/server.py.bak_toolcall_{ts}")

with open(SRC, "r") as f:
    s = f.read()

# Fix: in the `if have_vis:` branch, add tool_only check to pass through immediately
old = """                if have_vis:
                    if _looks_like_refusal(vis[:MAXC]):
                        detected = True
                        return
                    if len(vis) >= MAXC:
                        passed = True
                        return
                    if start_ts is not None and (_ztime.time() - start_ts) >= MAXW:
                        passed = True
                        return"""

new = """                if have_vis:
                    if _looks_like_refusal(vis[:MAXC]):
                        detected = True
                        return
                    if len(vis) >= MAXC:
                        passed = True
                        return
                    if start_ts is not None and (_ztime.time() - start_ts) >= MAXW:
                        passed = True
                        return
                    if tool_only:
                        passed = True
                        return"""

assert old in s, "OLD TEXT NOT FOUND"
s = s.replace(old, new)

with open(SRC, "w") as f:
    f.write(s)

# Verify syntax
import py_compile
py_compile.compile(SRC, doraise=True)
print("Syntax OK")

# Restart
r = subprocess.run(["docker", "restart", "tool-proxy"], capture_output=True, text=True, timeout=30)
print("restart:", r.returncode, r.stdout.strip())
print("DONE")
