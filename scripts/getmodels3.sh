#!/bin/bash
CID=coze-mysql
Q(){ docker exec "$CID" sh -lc "mysql -uroot -p\"\$MYSQL_ROOT_PASSWORD\" --default-character-set=utf8mb4 opencoze -N --raw -e \"$1\"" 2>&1 | grep -v "Using a password"; }
echo "COUNT:"; Q 'SELECT COUNT(*) FROM model_entity;'
echo "ENT_B64_BEGIN"
Q 'SELECT id, meta_id, name, scenario, status FROM model_entity LIMIT 200;' | base64 -w0
echo ""; echo "ENT_B64_END"
echo "META_B64_BEGIN"
Q 'SHOW TABLES LIKE "model%";';
Q 'SELECT * FROM model_meta LIMIT 200;' | base64 -w0
echo ""; echo "META_B64_END"
echo "INSTANCE_B64_BEGIN"
Q 'SELECT * FROM model_instance LIMIT 200;' | base64 -w0
echo ""; echo "INSTANCE_B64_END"
