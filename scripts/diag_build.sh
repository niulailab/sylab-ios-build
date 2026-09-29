#!/bin/bash
echo "=== 1) tool-proxy 内 flutter/dart/java 进程 ==="
docker exec tool-proxy ps aux 2>/dev/null | grep -iE "flutter|dart|java|gradle" | grep -v grep | head -10
echo
echo "=== 2) 测试目录是否存在 ==="
docker exec tool-proxy bash -c "ls -d /root/apk_test_* 2>/dev/null"
echo
echo "=== 3) Gradle 下载缓存大小（看是否在下载） ==="
docker exec tool-proxy bash -c "du -sh /root/.gradle 2>/dev/null; ls /root/.gradle/caches/ 2>/dev/null | head"
echo
echo "=== 4) Gradle daemon 日志最新行 ==="
docker exec tool-proxy bash -c "ls -t /root/.gradle/daemon/*/daemon-*.out.log 2>/dev/null | head -1 | xargs tail -15 2>/dev/null"
echo
echo "=== 5) 当前容器网络连接（看卡在哪个下载站） ==="
docker exec tool-proxy bash -c "(ss -tn 2>/dev/null || netstat -tn 2>/dev/null) | grep -iE 'ESTAB|SYN' | head -10"
echo
echo "=== 6) build 目录当前产物 ==="
docker exec tool-proxy bash -c "find /root/apk_test_*/build -name '*.apk' -o -name '*.dex' 2>/dev/null | head"
echo
echo "=== 7) Actions 任务在宿主机上的 SSH 进程 ==="
ps aux | grep -E "docker exec|flutter" | grep -v grep | head -5
echo "[DONE]"
