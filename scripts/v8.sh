#!/bin/bash
MP=$(docker exec coze-mysql printenv MYSQL_ROOT_PASSWORD)
echo "===== A. 所有 工具/插件/扩展/mcp 相关表 + 行数 ====="
for t in $(docker exec coze-mysql mysql -uroot -p"$MP" opencoze -N -e "SELECT table_name FROM information_schema.tables WHERE table_schema='opencoze' AND (table_name LIKE '%tool%' OR table_name LIKE '%plugin%' OR table_name LIKE '%extension%' OR table_name LIKE '%mcp%') ORDER BY table_name;" 2>/dev/null); do
  c=$(docker exec coze-mysql mysql -uroot -p"$MP" opencoze -N -e "SELECT COUNT(*) FROM \`$t\`;" 2>/dev/null)
  printf "  %-32s 行数=%s\n" "$t" "$c"
done

echo ""
echo "===== B. tool-proxy 容器所有含 bocha 的环境变量 ====="
docker exec tool-proxy printenv 2>/dev/null | grep -i bocha || echo "  (容器内无任何含 bocha 的环境变量)"

echo ""
echo "===== C. server.py 中读取/调用博查的代码位置 ====="
grep -nE -i "bocha|BOCHA_API_KEY|api.bochaai" /root/coze-studio/tool-proxy/server.py 2>/dev/null | head -25

echo ""
echo "===== D. Go运行时加载工具入口（MGet调用方 / chat链路取工具）====="
timeout 50 grep -rniE "\.MGet\(|GetToolsByVersion|ListAgentTools|GetVersionTools|agentToolVersion" /root/coze-studio/backend --include=*.go 2>/dev/null | grep -viE "_test|\.bak|/dal/|repository/tool_repository|gen.go" | head -15
echo "[DONE]"
