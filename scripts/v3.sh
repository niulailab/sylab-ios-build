#!/bin/bash
MP=$(docker exec coze-mysql printenv MYSQL_ROOT_PASSWORD)
Q(){ docker exec coze-mysql mysql -uroot -p"$MP" opencoze -N -e "$1" 2>/dev/null; }

echo "===== 1. 真正同名重复(同tool_name多行) ====="
Q "SELECT tool_name, COUNT(*) c FROM agent_tool_version WHERE agent_id=7669580347859795968 GROUP BY tool_name HAVING c>1;"
echo "(空=无同名重复)"

echo "===== 2. 按agent_version分布 ====="
Q "SELECT agent_version, COUNT(*) FROM agent_tool_version WHERE agent_id=7669580347859795968 GROUP BY agent_version;"

echo "===== 3. 同sub_url被多个不同tool_name映射(功能重叠) ====="
Q "SELECT sub_url, GROUP_CONCAT(tool_name) FROM agent_tool_version WHERE agent_id=7669580347859795968 GROUP BY method, sub_url HAVING COUNT(DISTINCT tool_name)>1;"

echo "===== 4. agent_version=1 的是哪些工具(当前bot版本能否加载) ====="
Q "SELECT tool_name, method, sub_url FROM agent_tool_version WHERE agent_id=7669580347859795968 AND agent_version=1;"
echo "[DONE]"
