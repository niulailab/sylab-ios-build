#!/bin/bash
echo "=== nginx 里 apks 目录的暴露规则 ==="
grep -rnE "chat-sdk|apks|alias|root" /etc/nginx/ 2>/dev/null | grep -vE "#|default_type" | head -15
echo
echo "=== 本机自测几个候选 URL ==="
for u in "http://127.0.0.1/apks/apk_build_test_20260929.apk" "http://127.0.0.1/apk/apk_build_test_20260929.apk"; do
  code=$(curl -s -o /dev/null -w "%{http_code}" -I "$u")
  echo "$code  $u"
done
echo "[DONE]"
