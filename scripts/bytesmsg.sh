#!/bin/bash
CID=coze-mysql
# 导出该消息 content 到文件，再分析
docker exec "$CID" sh -c 'mysql -uroot -p"$MYSQL_ROOT_PASSWORD" --default-character-set=utf8mb4 -N -e "SELECT content FROM opencoze.message WHERE id=7689879469758087168;" 2>/dev/null' > /tmp/msg768.raw
echo "total bytes: $(stat -c%s /tmp/msg768.raw)"
python3 - <<'PY'
raw=open('/tmp/msg768.raw','rb').read()
# mysql output is utf-8 already
s=raw.decode('utf-8','replace')
lines=s.split('\n')
print("num \\n-separated lines:",len(lines))
for i,l in enumerate(lines):
    print(f"L{i} star={l.count('*')} boldpair={l.count('**')} haslink={'[' in l and '](' in l} :: {l[:50]}")
# check the bold-link line specifically
import re
for l in lines:
    if 'muilh1pclynn' in l:
        print("\nLINE WITH URL, repr head/tail:")
        print(repr(l[:30]))
        print(repr(l[-30:]))
        # are asterisks ASCII 0x2A?
        stars=[(i,b) for i,b in enumerate(l.encode('utf-8')) if b==0x2A]
        print("ASCII * byte positions:",stars)
        m=re.search(r'\*\*(.+?)\*\*',l)
        print("bold regex matches:",bool(m))
        if m: print("inner len",len(m.group(1)))
PY