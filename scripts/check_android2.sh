#!/bin/bash
echo "=== 1) 宿主机 Android SDK 目录内容 ==="
ls -la /root/android-sdk/ 2>/dev/null
echo "  (空=没装)"
echo
echo "=== 2) Flutter SDK 里有没有捆绑的 Android 工具链 ==="
ls /root/flutter-sdk/bin/ 2>/dev/null | head
ls /root/flutter-sdk/bin/cache/ 2>/dev/null | head
echo
echo "=== 3) Java/JDK ==="
which java javac 2>/dev/null
java -version 2>&1 | head -3
ls /usr/lib/jvm/ 2>/dev/null
echo
echo "=== 4) Android cmdline-tools / platform-tools 是否曾经装过 ==="
find / -maxdepth 4 -name "sdkmanager" -o -name "cmdline-tools" -o -name "platform-tools" -o -name "build-tools" 2>/dev/null | head -10
echo
echo "=== 5) 隔离代码沙箱（executePython）的环境：是否挂载了 android-sdk ==="
grep -nE "createContainer|HostConfig|Binds|Mounts|volumes|android-sdk|flutter-sdk" /root/code_exec_server.js | head -20
echo
echo "=== 6) tool-proxy 的 /build_flutter 端点：APK 构建流程 ==="
grep -nE "build apk|flutter.*apk|android|gradlew" /root/code_exec_server.js | head -15
echo
echo "=== 7) tool-proxy 容器内 Flutter doctor（看工具链状态）==="
docker exec tool-proxy /root/flutter-sdk/bin/flutter doctor -v 2>&1 | head -40
echo "[DONE]"
