#!/bin/bash
MP=$(docker exec coze-mysql printenv MYSQL_ROOT_PASSWORD)
C(){ docker exec coze-mysql mysql -uroot -p"$MP" opencoze -e "$1" 2>/dev/null; }
echo "===== 当前版本绑定行样本(web_search/file_generate) 全字段 ====="
C "SELECT * FROM agent_tool_version WHERE agent_id=7669580347859795968 AND agent_version=7669597666208120832 AND sub_url IN('/v1/web-search','/v1/file/generate')\G"
echo "[DONE]"
