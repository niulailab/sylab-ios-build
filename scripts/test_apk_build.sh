#!/bin/bash
set -uo pipefail

TESTDIR=/root/apk_test_$(date +%s)
MAIN_B64=$(base64 -w0 <<'DART'
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
        body: const Center(
          child: Text(
            'Android build OK',
            style: TextStyle(fontSize: 24),
          ),
        ),
      ),
    );
  }
}
DART
)

echo "=== 1) 创建测试项目 $TESTDIR ==="
docker exec tool-proxy mkdir -p "$TESTDIR"
docker exec tool-proxy /root/flutter-sdk/bin/flutter create \
  --org com.test --project-name apk_test --platforms android "$TESTDIR" 2>&1 | tail -8
echo

echo "=== 2) 写入自定义 main.dart（非计数器模板） ==="
docker exec tool-proxy bash -c "echo '$MAIN_B64' | base64 -d > $TESTDIR/lib/main.dart"
docker exec tool-proxy head -5 "$TESTDIR/lib/main.dart"
echo

echo "=== 3) 接受 Android licenses ==="
docker exec tool-proxy bash -c "yes | /root/android-sdk/cmdline-tools/latest/bin/sdkmanager --licenses >/dev/null 2>&1 || true"
echo "licenses done"
echo

echo "=== 4) flutter build apk --release（开始计时）==="
date '+START %H:%M:%S'
docker exec tool-proxy bash -c "cd $TESTDIR && /root/flutter-sdk/bin/flutter build apk --release 2>&1" | tail -50
BUILD_RC=${PIPESTATUS[0]}
date '+END   %H:%M:%S'
echo "build exit code: $BUILD_RC"
echo

echo "=== 5) 检查 APK 产物 ==="
docker exec tool-proxy ls -la "$TESTDIR/build/app/outputs/flutter-apk/" 2>&1
echo

echo "=== 6) APK 包信息（aapt badging） ==="
docker exec tool-proxy bash -c "/root/android-sdk/build-tools/36.0.0/aapt dump badging $TESTDIR/build/app/outputs/flutter-apk/app-release.apk 2>/dev/null | head -12"
echo

echo "=== 7) APK SHA256 + 大小 ==="
docker exec tool-proxy bash -c "sha256sum $TESTDIR/build/app/outputs/flutter-apk/app-release.apk; du -h $TESTDIR/build/app/outputs/flutter-apk/app-release.apk"
echo

echo "=== 8) 清理测试目录 ==="
docker exec tool-proxy rm -rf "$TESTDIR"
echo "cleaned $TESTDIR"
echo "[DONE]"
