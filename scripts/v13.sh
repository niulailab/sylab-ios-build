#!/bin/bash
MP=$(docker exec coze-mysql printenv MYSQL_ROOT_PASSWORD)
Q(){ docker exec coze-mysql mysql -uroot -p"$MP" opencoze -N -e "$1" 2>/dev/null; }
C(){ docker exec coze-mysql mysql -uroot -p"$MP" opencoze -e "$1" 2>/dev/null; }

echo "===== 视频工具绑定行(agent_version=1) ====="
C "SELECT id,agent_id,plugin_id,tool_id,agent_version,tool_name,tool_version,sub_url,method,source FROM agent_tool_version WHERE sub_url IN('/video/generate','/video/status/{task_id}')\G"

echo "===== 这两个 tool_id 在 tool 表是否存在/激活 ====="
Q "SELECT t.id,t.sub_url,t.activated_status,t.plugin_id FROM tool t WHERE t.id IN (SELECT tool_id FROM agent_tool_version WHERE sub_url IN('/video/generate','/video/status/{task_id}'));"

echo ""
echo "===== /screenshot 在 agent_tool_version 绑定行 ====="
C "SELECT id,tool_id,agent_version,tool_name,sub_url,method FROM agent_tool_version WHERE sub_url='/screenshot'\G"
echo "===== 其 tool_id 在 tool 表 sub_url ====="
Q "SELECT id,sub_url,activated_status FROM tool WHERE id IN (SELECT tool_id FROM agent_tool_version WHERE sub_url='/screenshot');"

echo ""
echo "===== 运行时加载源码定位 ====="
find /root/coze-studio -name "agent_tool_version.go" 2>/dev/null
echo "--- MGet 之后是否 JOIN tool 表: grep toolRepo in agent tool service ---"
grep -rn "func.*MGet\|toolRepo\|ToolVersion\|operation" $(find /root/coze-studio -path "*tool/agent_tool_version.go" 2>/dev/null | head -1) 2>/dev/null | head -25
echo "[DONE]"
