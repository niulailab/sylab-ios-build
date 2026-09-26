#!/bin/bash
# 先把真实全文导出 base64
CID=coze-mysql
docker exec "$CID" sh -c 'mysql -uroot -p"$MYSQL_ROOT_PASSWORD" --default-character-set=utf8mb4 -N -e "SELECT content FROM opencoze.message WHERE id=7689879469758087168;" 2>/dev/null' > /tmp/msg768.raw
echo "BASE64_BEGIN"
base64 -w0 /tmp/msg768.raw
echo
echo "BASE64_END"
# 检查是否含 %
python3 -c "
s=open('/tmp/msg768.raw','rb').read().decode('utf-8','replace')
print('percent count:',s.count('%'))
import urllib.parse
try:
    d=urllib.parse.unquote(s)
    print('decode changes:',d!=s)
except Exception as e:print('decode err',e)
print('literal backslash-n count:',s.count(chr(92)+'n'))
print('real newline count:',s.count(chr(10)))
"