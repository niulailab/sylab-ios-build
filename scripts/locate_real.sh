#!/bin/bash
python3 - <<'PYEOF'
import json, subprocess, datetime
def mysql(sql):
    out=subprocess.run(['docker','exec','-e','Q='+sql,'coze-mysql','sh','-c',
      'mysql -uroot -p"" -N --default-character-set=utf8mb4 -e ""'],capture_output=True)
    return out.stdout.decode('utf-8','replace')
# 所有“这套提炼”及时间
rows=mysql("SELECT id,conversation_id,created_at,LENGTH(content) FROM opencoze.message WHERE role='user' AND content LIKE '%这套提炼%' ORDER BY id DESC LIMIT 6;")
for line in rows.splitlines():
    p=line.split('\t')
    ts=datetime.datetime.utcfromtimestamp(int(p[2])/1000)+datetime.timedelta(hours=8)
    print('id=%s conv=%s time=%s len=%s'%(p[0],p[1],ts,p[3]))
# 第二候选会话消息数
for cid in ['7689892369646223360','7690220266571431936']:
    c=mysql("SELECT COUNT(*) FROM opencoze.message WHERE conversation_id=%s;"%cid).strip()
    print('conv',cid,'count',c)
PYEOF
