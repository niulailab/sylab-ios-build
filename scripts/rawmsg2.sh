#!/bin/bash
F=/root/sylab-app/src/components/MarkdownRenderer.tsx
echo "===== search book emoji / link card across src ====="
grep -rn $'\360\237\223\226' /root/sylab-app/src 2>/dev/null | head -20
echo "----- grep card/preview/link unfurl -----"
grep -nE "LinkCard|linkCard|previewCard|unfurl|book|📖|LinkPreview|urlCard" "$F" | head
echo
echo "===== full latest msg content base64 ====="
CID=coze-mysql
docker exec "$CID" sh -c 'mysql -uroot -p"$MYSQL_ROOT_PASSWORD" --default-character-set=utf8mb4 -N -e "SELECT content FROM opencoze.message WHERE id=7689881897517711360;" 2>/dev/null' | base64 -w0
echo
echo "===== second msg base64 ====="
docker exec "$CID" sh -c 'mysql -uroot -p"$MYSQL_ROOT_PASSWORD" --default-character-set=utf8mb4 -N -e "SELECT content FROM opencoze.message WHERE id=7689881664771588096;" 2>/dev/null' | base64 -w0
echo