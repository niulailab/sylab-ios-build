#!/bin/bash
set -e
JL=/etc/fail2ban/jail.local
echo "===== merge duplicate [sshd] + ensure ignoreip (python) ====="
python3 - "$JL" <<'PY'
import sys,re
p=sys.argv[1]
lines=open(p).read().splitlines()
# parse sections
secs=[]   # (name, [lines])
cur=('__top__',[])
for ln in lines:
    m=re.match(r'^\s*\[([^\]]+)\]\s*$',ln)
    if m:
        secs.append(cur); cur=(m.group(1).strip(),[])
    else:
        cur[1].append(ln)
secs.append(cur)
# merge duplicate sshd into first
names=[s[0] for s in secs]
if names.count('sshd')>1:
    first=next(i for i,s in enumerate(secs) if s[0]=='sshd')
    keep=[]
    for i,s in enumerate(secs):
        if s[0]=='sshd' and i!=first:
            secs[first][1].extend(s[1])
        else:
            keep.append(i)
    secs=[secs[i] for i in keep]
# dedupe keys & merge ignoreip within sshd
for si,s in enumerate(secs):
    if s[0]!='sshd': continue
    body=s[1]; seen={}; order=[]
    for ln in body:
        mm=re.match(r'^\s*([\w.-]+)\s*=',ln)
        if mm:
            k=mm.group(1)
            if k in seen:
                if k=='ignoreip':
                    # merge tokens
                    base=body[seen[k]]
                    extra=re.sub(r'^[^=]*=','',ln).split()
                    curtok=re.sub(r'^[^=]*=','',base).split()
                    for t in extra:
                        if t not in curtok: curtok.append(t)
                    body[seen[k]]=re.match(r'^[^=]*=',base).group(0)+' '+' '.join(curtok)
                continue
            seen[k]=len(order)
        order.append(ln)
    secs[si]=(s[0],order)
    # ensure ignoreip has target
    body=secs[si][1]
    ip='82.156.201.157'
    ii=[i for i,ln in enumerate(body) if re.match(r'^\s*ignoreip\s*=',ln)]
    if ii:
        i=ii[0]; tok=re.sub(r'^[^=]*=','',body[i]).split()
        if ip not in tok: tok.append(ip)
        body[i]=re.match(r'^[^=]*=',body[i]).group(0)+' '+' '.join(tok)
    else:
        body.insert(0,f'ignoreip = 127.0.0.1/8 ::1 {ip}')
# emit
out=[]
for name,body in secs:
    if name!='__top__': out.append(f'[{name}]')
    out.extend(body)
open(p,'w').write('\n'.join(out).rstrip()+'\n')
print("merged. ignoreip now:")
for ln in out:
    if re.match(r'^\s*ignoreip',ln): print("  ",ln)
PY
fail2ban-client -t
fail2ban-client reload sshd
fail2ban-client set sshd unbanip 82.156.201.157 || true
echo "--- sshd sections in file ---"; grep -n '^\[sshd\]' "$JL"
fail2ban-client status sshd | grep -i banned

echo "===== precise table query (conversation 7687609248154386432) ====="
M=$(docker ps --format '{{.Names}}' | grep -i mysql | head -1)
docker exec "$M" mysql -ucoze -p'VK4DxMi0giMQAE5Xpyqo' -h127.0.0.1 opencoze -N -e "
SELECT COUNT(*) AS total,
SUM(content LIKE '%|%') AS with_pipe,
SUM(content REGEXP '\\\\|[[:space:]]*-{2,}[[:space:]]*\\\\|') AS with_tablesep
FROM message WHERE conversation_id='7687609248154386432';
SELECT id, role, LENGTH(content) FROM message
WHERE conversation_id='7687609248154386432'
AND content REGEXP '\\\\|[[:space:]]*-{2,}[[:space:]]*\\\\|';
" 2>&1 | grep -v "Using a password"
