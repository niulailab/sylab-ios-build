#!/bin/bash
MP=$(docker exec coze-mysql printenv MYSQL_ROOT_PASSWORD)
echo "### 该bot绑定的全部工具 ###"
docker exec coze-mysql mysql -uroot -p"$MP" opencoze -e "
SELECT tool_name, sub_url, method FROM agent_tool_version 
WHERE agent_id=7669580347859795968 ORDER BY id;" 2>/dev/null
echo ""
echo "### 其中是否有 video 相关 ###"
docker exec coze-mysql mysql -uroot -p"$MP" opencoze -N -e "
SELECT COUNT(*) FROM agent_tool_version WHERE agent_id=7669580347859795968 AND tool_name LIKE '%video%';" 2>/dev/null
echo "[DONE]"
