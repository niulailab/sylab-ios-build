#!/bin/bash
CID=coze-mysql
echo "===== ALL msgs with link: id/conversation/display_content present? ====="
docker exec "$CID" sh -c 'mysql -uroot -p"$MYSQL_ROOT_PASSWORD" --default-character-set=utf8mb4 -N -e "SELECT id, conversation_id, LENGTH(content), LENGTH(display_content), content_type, created_at FROM opencoze.message WHERE content LIKE \"%muilh1pclynn%\" ORDER BY id;" 2>/dev/null'
echo
echo "===== any content containing book emoji (F0 9F 93 96) ====="
docker exec "$CID" sh -c 'mysql -uroot -p"$MYSQL_ROOT_PASSWORD" --default-character-set=utf8mb4 -N -e "SELECT id, LEFT(content,120) FROM opencoze.message WHERE content LIKE \"%📖%\" ORDER BY id DESC LIMIT 5;" 2>/dev/null'
echo
echo "===== grep book emoji whole app dir (not just src) ====="
grep -rln $'\360\237\223\226' /root/sylab-app/app /root/sylab-app/src /root/sylab-app/components 2>/dev/null | head
echo "===== grep open-book unicode literal ====="
grep -rnE "1F4D6|\\\\ud83d\\\\udcd6|📖" /root/sylab-app/app /root/sylab-app/src 2>/dev/null | head