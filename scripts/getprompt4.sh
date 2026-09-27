#!/bin/bash
CID=coze-mysql
echo "PROMPT_B64_BEGIN"
docker exec "$CID" sh -lc 'mysql -uroot -p"$MYSQL_ROOT_PASSWORD" opencoze -N --raw -e "SELECT prompt FROM single_agent_draft WHERE agent_id=7669580347859795968;"' 2>/dev/null | base64 -w0
echo ""
echo "PROMPT_B64_END"
echo "MODELINFO_B64_BEGIN"
docker exec "$CID" sh -lc 'mysql -uroot -p"$MYSQL_ROOT_PASSWORD" opencoze -N --raw -e "SELECT model_info FROM single_agent_draft WHERE agent_id=7669580347859795968;"' 2>/dev/null | base64 -w0
echo ""
echo "MODELINFO_B64_END"
