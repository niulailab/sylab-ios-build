#!/bin/bash
echo "===== browser/content、screenshot 路由定义与转发 ====="
grep -nE "browser/content|/screenshot|browser-service|BROWSER_SERVICE|browser_content|anti_bot|def .*content|def .*screenshot" /root/coze-studio/tool-proxy/server.py 2>/dev/null | head -20
echo ""
echo "===== browser 相关容器 ====="
docker ps --format '{{.Names}}\t{{.Status}}' | grep -iE "browser|playwright|chrome"
echo ""
echo "===== 看 content/screenshot 处理代码块（定位行号后打印）====="
L=$(grep -nE "@app.post\(.*browser/content|@app.*screenshot|@app.post\(.?/screenshot" /root/coze-studio/tool-proxy/server.py | head)
echo "$L"
echo "[DONE]"
