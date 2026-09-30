#!/bin/bash
TS=$(date +%Y%m%d_%H%M%S)
BK=/root/backup_rootfix_$TS
mkdir -p "$BK"
cp /root/coze-studio/tool-proxy/server.py "$BK/server.py"
cp /root/coze-studio/docker/docker-compose.yml "$BK/docker-compose.yml"
MP=$(docker exec coze-mysql printenv MYSQL_ROOT_PASSWORD)
docker exec coze-mysql mysqldump -uroot -p"$MP" opencoze tool tool_version tool_draft agent_tool_version agent_tool_draft plugin plugin_version plugin_draft > "$BK/opencoze_tables.sql" 2>/dev/null
echo "备份目录: $BK"
ls -la "$BK"
echo ""
echo "===== 博查 Authorization 头原始字节(确认是否字面***) ====="
grep -n "Authorization" /root/coze-studio/tool-proxy/server.py | grep -i "Bearer" | sed -n '1,8p'
echo "--- 2870行附近 cat -A(看星号还是占位) ---"
sed -n '2869,2872p' /root/coze-studio/tool-proxy/server.py
echo "[DONE]"
