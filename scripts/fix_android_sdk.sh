#!/bin/bash
set -euo pipefail

echo "=== 1) 查看 /opt/android-sdk 现有内容 ==="
ls /opt/android-sdk/ 2>/dev/null
echo "大小:"
du -sh /opt/android-sdk/ 2>/dev/null
echo
echo "=== 2) 查看 /opt/android-sdk 子目录 ==="
for d in platform-tools cmdline-tools build-tools platforms; do
  echo "--- $d ---"
  ls /opt/android-sdk/$d/ 2>/dev/null || echo "  (不存在)"
done
echo
echo "=== 3) 删除空目录，建软链到 /opt/android-sdk ==="
# 备份（如果有内容）
if [ -d /root/android-sdk ] && [ "$(ls -A /root/android-sdk 2>/dev/null)" ]; then
  mv /root/android-sdk /root/android-sdk.bak.$(date +%s)
fi
rm -rf /root/android-sdk
ln -s /opt/android-sdk /root/android-sdk
ls -la /root/android-sdk
echo
echo "=== 4) 验证 tool-proxy 容器内能访问 ==="
docker restart tool-proxy
sleep 8
docker exec tool-proxy ls /root/android-sdk/ 2>/dev/null | head
echo
echo "=== 5) tool-proxy 容器内 flutter doctor（Android 工具链）==="
docker exec tool-proxy /root/flutter-sdk/bin/flutter doctor -v 2>&1 | grep -A5 "Android toolchain"
echo
echo "=== 6) 设置环境变量（tool-proxy 容器内） ==="
# 检查 tool-proxy 启动脚本里有没有 ENV 设置
docker inspect tool-proxy --format '{{json .Config.Env}}' | python3 -m json.tool 2>/dev/null | grep -iE "android|flutter|java|jdk"
echo
echo "=== 7) 列出缺失的 SDK 组件（platforms / licenses 等） ==="
# 检查是否有 platforms/android-xx
ls /opt/android-sdk/platforms/ 2>/dev/null
echo
echo "=== 8) 检查 sdkmanager 是否可用 ==="
ls /opt/android-sdk/cmdline-tools/*/bin/sdkmanager 2>/dev/null || echo "没有 cmdline-tools"
echo "[DONE]"
