#!/bin/bash
CID=coze-mysql
docker exec "$CID" sh -lc 'mysql -uroot -p"$MYSQL_ROOT_PASSWORD" --default-character-set=utf8mb4 opencoze -N --raw -e "SHOW COLUMNS FROM model_instance;"' 2>/dev/null
echo "ROW15_B64_BEGIN"
docker exec "$CID" sh -lc 'mysql -uroot -p"$MYSQL_ROOT_PASSWORD" --default-character-set=utf8mb4 opencoze -N --raw -e "SELECT * FROM model_instance WHERE id=100015;"' 2>/dev/null | base64 -w0
echo ""; echo "ROW15_B64_END"
