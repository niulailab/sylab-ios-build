#!/bin/bash
CID=$(docker ps --format '{{.Names}}'|grep -i mysql|head -1)
cat > /tmp/_q.sql <<'SQL'
SHOW COLUMNS FROM model_instance;
SELECT * FROM model_instance WHERE id IN (100012,100015)\G
SQL
cat /tmp/_q.sql | docker exec -i "$CID" sh -lc 'mysql -uroot -p"$MYSQL_ROOT_PASSWORD" --default-character-set=utf8mb4 opencoze 2>&1' | grep -v "Using a password"
echo DONE
