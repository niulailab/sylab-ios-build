#!/bin/bash
CID=coze-mysql
Q(){ docker exec "$CID" sh -lc "mysql -uroot -p\"\$MYSQL_ROOT_PASSWORD\" --default-character-set=utf8mb4 opencoze -N --raw -e \"$1\"" 2>&1 | grep -v "Using a password"; }
echo "COLS_MODEL_ENTITY"
Q 'SHOW COLUMNS FROM model_entity;'
echo "MODEL_B64_BEGIN"
Q 'SELECT * FROM model_entity WHERE id=100015;' | base64 -w0
echo ""; echo "MODEL_B64_END"
echo "META_B64_BEGIN"
Q 'SELECT * FROM model_meta;' | base64 -w0
echo ""; echo "META_B64_END"
echo "ENTLIST_B64_BEGIN"
Q 'SELECT id,name FROM model_entity ORDER BY id;' | base64 -w0
echo ""; echo "ENTLIST_B64_END"
