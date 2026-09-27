#!/bin/bash
echo "===== TIME ====="; date
MC=coze-mysql
runmysql(){ docker exec -e Q="$1" "$MC" sh -lc 'mysql -uroot -p"$MYSQL_ROOT_PASSWORD" -N -e "$Q" 2>/dev/null'; }
echo "===== test conversations msg counts ====="
runmysql "SELECT m.conversation_id, COUNT(*) c FROM opencoze.message m JOIN opencoze.conversation c ON c.id=m.conversation_id WHERE c.creator_id=17857736066221234 GROUP BY m.conversation_id ORDER BY c DESC LIMIT 8;"

# 直接登录拿 cookie
curl -s -m 10 -D /tmp/_hdr -X POST "http://127.0.0.1:9091/api/passport/web/email/login/" \
  -H 'Content-Type: application/json' -d '{"email":"test@sylab.com","password":"123456"}' >/dev/null
SK=$(grep -i "set-cookie" /tmp/_hdr | sed -n 's/.*session_key=\([^;]*\).*/\1/p' | head -1)

# 取测试号消息最多的会话（直接SQL）
CID=$(runmysql "SELECT m.conversation_id FROM opencoze.message m JOIN opencoze.conversation c ON c.id=m.conversation_id WHERE c.creator_id=17857736066221234 GROUP BY m.conversation_id ORDER BY COUNT(*) DESC LIMIT 1;")
echo "target conv: $CID  (count: $(runmysql "SELECT COUNT(*) FROM opencoze.message WHERE conversation_id=$CID;"))"

for P in 1 2 3; do
echo "===== page$P (cookie only) ====="
curl -s -m 10 -X POST "http://127.0.0.1:9091/v1/conversation/message/list" \
  -H 'Content-Type: application/json' -H "Cookie: session_key=$SK" \
  -d "{\"conversation_id\":\"$CID\",\"page_num\":$P,\"page_size\":50}" \
  | python3 -c "
import sys,json
try:
  d=json.load(sys.stdin)
except Exception as e:
  print('NON-JSON', sys.stdin.read()[:200]); raise SystemExit
print('code=',d.get('code'),'msg=',d.get('msg'))
data=d.get('data')
def count(x):
  if isinstance(x,list):return len(x)
  if isinstance(x,dict):
    for k in ('messages','items','list','data'):
      if isinstance(x.get(k),list):return len(x[k])
  return type(x).__name__
print('data_len=',count(data))
if isinstance(data,dict): print('keys=',list(data.keys()), 'has_more=',data.get('has_more'))
"
done
echo "===== DONE ====="
