#!/bin/bash
CID=coze-mysql
Q(){ docker exec "$CID" sh -lc "mysql -uroot -p\"\$MYSQL_ROOT_PASSWORD\" --default-character-set=utf8mb4 opencoze -N --raw -e \"$1\"" 2>/dev/null; }
echo "PROMPT_B64_BEGIN"
Q 'SELECT prompt FROM single_agent_draft WHERE agent_id=7669580347859795968;' | base64 -w0
echo ""; echo "PROMPT_B64_END"
echo "MODELINFO_B64_BEGIN"
Q 'SELECT model_info FROM single_agent_draft WHERE agent_id=7669580347859795968;' | base64 -w0
echo ""; echo "MODELINFO_B64_END"
echo "NAME_B64_BEGIN"
Q 'SELECT name FROM single_agent_draft WHERE agent_id=7669580347859795968;' | base64 -w0
echo ""; echo "NAME_B64_END"
