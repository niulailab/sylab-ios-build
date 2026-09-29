#!/bin/bash
MP=$(docker exec coze-mysql printenv MYSQL_ROOT_PASSWORD)
echo "===== 该bot注册工具总数(按agent_id) ====="
docker exec coze-mysql mysql -uroot -p"$MP" opencoze -e "SELECT COUNT(*) FROM agent_tool_version WHERE agent_id=7669580347859795968;" 2>/dev/null
echo ""
echo "===== 去重工具名 + 来源 + method/sub_url ====="
docker exec coze-mysql mysql -uroot -p"$MP" opencoze -e "SELECT tool_name, method, sub_url, source, COUNT(*) cnt FROM agent_tool_version WHERE agent_id=7669580347859795968 GROUP BY tool_name ORDER BY tool_name;" 2>/dev/null
echo ""
echo "===== 全部原始行(含重复)，看同tool_name是否多条 ====="
docker exec coze-mysql mysql -uroot -p"$MP" opencoze -e "SELECT tool_name, method, sub_url, agent_version, source FROM agent_tool_version WHERE agent_id=7669580347859795968 ORDER BY tool_name, agent_version;" 2>/dev/null
echo "[DONE]"
