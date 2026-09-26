#!/bin/bash
CID=coze-mysql
Q(){ docker exec "$CID" sh -c "mysql -uroot -p\"\$MYSQL_ROOT_PASSWORD\" --default-character-set=utf8mb4 -N -e \"$1\" 2>/dev/null"; }
echo "===== for several recent assistant msgs: literal \\n vs real newline counts ====="
Q "SELECT id,
  (LENGTH(content)-LENGTH(REPLACE(content,'\\\\n','')))/2 AS lit_n,
  LENGTH(content)-LENGTH(REPLACE(content,CHAR(10),'')) AS real_n,
  LENGTH(model_content)-LENGTH(REPLACE(model_content,'\\\\n','')) AS m_lit,
  LENGTH(model_content)-LENGTH(REPLACE(model_content,CHAR(10),'')) AS m_real
FROM opencoze.message WHERE id IN (7689879469758087168,7689881897517711360,7689881664771588096,7689881337271943168);"
echo
echo "===== display_content for target (first 200 chars) ====="
Q "SELECT LEFT(display_content,200) FROM opencoze.message WHERE id=7689879469758087168;"
echo
echo "===== how many assistant msgs today contain literal backslash-n ====="
Q "SELECT COUNT(*) FROM opencoze.message WHERE role='assistant' AND content LIKE '%\\\\n%';"
echo "===== and total assistant msgs today ====="
Q "SELECT COUNT(*) FROM opencoze.message WHERE role='assistant';"