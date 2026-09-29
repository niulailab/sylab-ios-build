#!/bin/bash

# === 容器内执行的构建脚本 ===
cat > /tmp/run_apk_inner.sh <<'INNER'
#!/bin/bash
LOG=/tmp/apk_build.log
STATUS=/tmp/apk_status.txt
echo "RUNNING start=$(date +%H:%M:%S)" > $STATUS
exec > $LOG 2>&1

TESTDIR=/root/apk_test2
rm -rf "$TESTDIR"
/root/flutter-sdk/bin/flutter create --org com.test --project-name apk_test --platforms android "$TESTDIR"

cat > "$TESTDIR/lib/main.dart" <<'DART'
import 'package:flutter/material.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'APK Build Test',
      home: Scaffold(
        appBar: AppBar(title: const Text('APK Build Test')),
        body: const Center(child: Text('Android build OK', style: TextStyle(fontSize: 24))),
      ),
    );
  }
}
DART

yes | /root/android-sdk/cmdline-tools/latest/bin/sdkmanager --licenses >/dev/null 2>&1 || true

cd "$TESTDIR"
/root/flutter-sdk/bin/flutter build apk --release
RC=$?
echo "build rc=$RC end=$(date +%H:%M:%S)"
if [ $RC -eq 0 ] && [ -f "$TESTDIR/build/app/outputs/flutter-apk/app-release.apk" ]; then
  cp "$TESTDIR/build/app/outputs/flutter-apk/app-release.apk" /tmp/test_app-release.apk
  echo "SUCCESS end=$(date +%H:%M:%S)" > $STATUS
else
  echo "FAILED end=$(date +%H:%M:%S)" > $STATUS
fi
rm -rf "$TESTDIR"
INNER

echo "=== 1) 投递脚本进容器 ==="
docker cp /tmp/run_apk_inner.sh tool-proxy:/tmp/run_apk_inner.sh
docker exec tool-proxy rm -f /tmp/apk_status.txt /tmp/apk_build.log /tmp/test_app-release.apk

echo "=== 2) detached 启动 ==="
docker exec -d tool-proxy bash /tmp/run_apk_inner.sh
sleep 8
docker exec tool-proxy ps aux | grep -E "run_apk_inner|flutter_tools|dart" | grep -v grep | head -3
echo

echo "=== 3) 轮询状态（依赖已缓存，预计几分钟） ==="
FINAL=""
for i in $(seq 1 40); do
  sleep 15
  S=$(docker exec tool-proxy cat /tmp/apk_status.txt 2>/dev/null || echo "WAIT")
  echo "poll $i ($(date +%H:%M:%S)): $S"
  case "$S" in
    SUCCESS*) FINAL="SUCCESS"; break;;
    FAILED*)  FINAL="FAILED"; break;;
  esac
done
echo

echo "=== 4) 构建日志尾部 ==="
docker exec tool-proxy tail -25 /tmp/apk_build.log
echo

if [ "$FINAL" = "SUCCESS" ]; then
  echo "=== 5) APK 验证 ==="
  docker exec tool-proxy ls -la /tmp/test_app-release.apk
  docker exec tool-proxy /root/android-sdk/build-tools/36.0.0/aapt dump badging /tmp/test_app-release.apk 2>/dev/null | grep -E "package:|application-label:|sdkVersion|targetSdkVersion|native-code"
  docker exec tool-proxy sha256sum /tmp/test_app-release.apk
  echo
  echo "=== 6) APK 投递到下载目录 ==="
  docker cp tool-proxy:/tmp/test_app-release.apk /tmp/test_app-release.apk
  mkdir -p /var/www/chat-sdk/apks
  cp /tmp/test_app-release.apk /var/www/chat-sdk/apks/apk_build_test_$(date +%Y%m%d).apk
  ls -la /var/www/chat-sdk/apks/ | tail -5
fi
echo "[DONE] FINAL=$FINAL"
