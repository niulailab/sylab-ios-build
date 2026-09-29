#!/bin/bash
# 构建脚本写到 bind mount 目录（宿主机 /root/coze-studio/tool-proxy/ = 容器 /app/）

cat > /root/coze-studio/tool-proxy/run_apk_build.sh <<'INNER'
#!/bin/bash
LOG=/app/apk_build.log
STATUS=/app/apk_status.txt
APKOUT=/app/test_app-release.apk
echo "RUNNING start=$(date +%H:%M:%S)" > $STATUS
exec > $LOG 2>&1
set -x

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
  cp "$TESTDIR/build/app/outputs/flutter-apk/app-release.apk" "$APKOUT"
  ls -la "$APKOUT"
  /root/android-sdk/build-tools/36.0.0/aapt dump badging "$APKOUT" | head -8
  sha256sum "$APKOUT"
  echo "SUCCESS end=$(date +%H:%M:%S)" > $STATUS
else
  echo "FAILED end=$(date +%H:%M:%S)" > $STATUS
fi
rm -rf "$TESTDIR"
INNER
chmod +x /root/coze-studio/tool-proxy/run_apk_build.sh

echo "=== 清理旧状态 ==="
rm -f /root/coze-studio/tool-proxy/apk_status.txt /root/coze-studio/tool-proxy/apk_build.log /root/coze-studio/tool-proxy/test_app-release.apk

echo "=== 先看历史 daemon 日志里上次构建结果 ==="
docker exec tool-proxy bash -c "grep -hE 'BUILD SUCCESSFUL|BUILD FAILED' /root/.gradle/daemon/*/daemon-*.out.log 2>/dev/null | tail -5" || echo "无历史结果"

echo "=== detached 启动构建 ==="
docker exec -d tool-proxy bash /app/run_apk_build.sh
sleep 5
echo "=== 容器内进程确认 ==="
docker exec tool-proxy ps aux | grep -E "run_apk|flutter|gradle|java" | grep -v grep | head -5
echo
echo "=== 状态文件 ==="
cat /root/coze-studio/tool-proxy/apk_status.txt 2>/dev/null
echo "[DONE]"
