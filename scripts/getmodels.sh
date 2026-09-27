#!/bin/bash
CID=coze-mysql
Q(){ docker exec "$CID" sh -lc "mysql -uroot -p\"\$MYSQL_ROOT_PASSWORD\" --default-character-set=utf8mb4 opencoze -N --raw -e \"$1\"" 2>/dev/null; }
echo "MODEL_B64_BEGIN"
Q 'SELECT id, name, model_meta_id, CONVERT(model_info USING utf8mb4) FROM model_entity WHERE id=100015;' | base64 -w0
echo ""; echo "MODEL_B64_END"
echo "META_B64_BEGIN"
Q 'SELECT id, name FROM model_meta;' | base64 -w0
echo ""; echo "META_B64_END"
echo "ENTLIST_B64_BEGIN"
Q 'SELECT id, name FROM model_entity ORDER BY id;' | base64 -w0
echo ""; echo "ENTLIST_B64_END"
echo "PUBPROMPT_B64_BEGIN"
Q 'SELECT prompt FROM single_agent_version WHERE agent_id=7669580347859795968 ORDER BY id DESC LIMIT 1;' | base64 -w0
echo ""; echo "PUBPROMPT_B64_END"
