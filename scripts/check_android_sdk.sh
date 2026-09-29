#!/bin/bash

echo "=== 1) tool-proxy 容器里 Android SDK/Flutter 挂载 ==="
docker inspect tool-proxy --format '{{json .Mounts}}' | python3 -c "
import json,sys
for m in json.loads(sys.stdin.read()):
    if any(k in m['Source'].lower() for k in ['android','flutter','sdk']):
        print(f\"  {m['Source']} -> {m['Destination']} (rw={m['RW']})\")
"
echo
echo "=== 2) 隔离代码执行容器（coderunner）情况 ==="
docker ps --filter "ancestor=coderunner" --format '{{.ID}}\t{{.Names}}\t{{.Status}}' 2>/dev/null
docker ps --format '{{.Names}}\t{{.Image}}' | grep -iE "code|runner|sandbox|isolat"
echo
echo "=== 3) 当前宿主机上的 Android SDK ==="
ls -la /root/android-sdk/ 2>/dev/null | head -15
echo
echo "=== 4) ANDROID_HOME / ANDROID_SDK_ROOT ==="
env | grep -i android
echo
echo "=== 5) tool-proxy 容器里能看到 Android SDK 吗？ ==="
docker exec tool-proxy ls /root/android-sdk/ 2>/dev/null | head -10 || echo "tool-proxy 看不到 /root/android-sdk"
docker exec tool-proxy ls /root/flutter-sdk/ 2>/dev/null | head -10 || echo "tool-proxy 看不到 /root/flutter-sdk"
echo
echo "=== 6) code_exec_server.js 里 executePython 的容器创建参数 ==="
grep -nE "docker.*run|create.*container|android|flutter|sdk|DANGER_PATTERN|network|read_only|isolat" /root/code_exec_server.js | head -30
echo
echo "=== 7) 当前正在运行的隔离容器（如果有） ==="
docker ps --format '{{.Names}}\t{{.Image}}\t{{.Status}}' | grep -v tool-proxy | grep -v browser | head -20
echo "[DONE]"
