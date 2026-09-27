#!/bin/bash
CID=coze-mysql
docker exec "$CID" sh -lc 'mysql -uroot -p"$MYSQL_ROOT_PASSWORD" --default-character-set=utf8mb4 opencoze -N --raw -e "SELECT id, connection FROM model_instance WHERE id BETWEEN 100012 AND 100015;"' 2>/dev/null
echo DONE
