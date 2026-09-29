#!/bin/bash
echo "=== 真实域名访问（s.symsgf.xyz 回源 8099）==="
curl -sIL "https://s.symsgf.xyz/apks/apk_build_test_20260929.apk" 2>&1 | grep -iE "HTTP/|content-length|content-type|location" | head -10
echo
echo "=== 8099 本机直连 ==="
curl -sk -o /dev/null -w "http=%{http_code} size=%{size_download} type=%{content_type}\n" -I "https://127.0.0.1:8099/apks/apk_build_test_20260929.apk"
echo "[DONE]"
