#!/bin/bash
MP=$(docker exec coze-mysql printenv MYSQL_ROOT_PASSWORD)
M(){ docker exec coze-mysql mysql -uroot -p"$MP" opencoze -e "$1" 2>/dev/null; }

echo "### tool表结构 ###"
M "SELECT column_name FROM information_schema.columns WHERE table_schema='opencoze' AND table_name='tool' ORDER BY ordinal_position;" | head -20
echo ""
echo "### agent_tool_version 里该bot绑定的工具 ###"
M "SELECT * FROM agent_tool_version WHERE agent_id=7669580347859795968 LIMIT 5\G" 2>&1 | head -30
echo ""
echo "### single_agent_version 工具配置字段 ###"
M "SELECT column_name FROM information_schema.columns WHERE table_schema='opencoze' AND table_name='single_agent_version' AND (column_name LIKE '%tool%' OR column_name LIKE '%plugin%');"
echo "[DONE]"
