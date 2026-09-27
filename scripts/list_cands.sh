#!/bin/bash
python3 - <<'PYEOF'
import subprocess, datetime
def mysql(sql):
    p=subprocess.run(['docker','exec','-e','Q='+sql,'coze-mysql','sh','-c',
      'mysql -uroot -p"$MYSQL_ROOT_PASSWORD" -N --default-character-set=utf8mb4 -e "$Q" 2>&1'],capture_output=True)
    return p.stdout.decode('utf-8','replace'), p.returncode
for cid in ['7689892369646223360','7690220266571431936']:
    out,rc=mysql("SELECT id,role,created_at,LENGTH(content) FROM opencoze.message WHERE conversation_id=%s ORDER BY id;"%cid)
    print('==== conv',cid,'====')
    for line in out.splitlines():
        q=line.split('\t')
        if len(q)<4: print(line); continue
        try: ts=datetime.datetime.utcfromtimestamp(int(q[2])/1000)+datetime.timedelta(hours=8)
        except: ts='?'
        print(' ',q[1],str(ts)[5:19],'len='+q[3])
PYEOF
