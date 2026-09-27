#!/bin/bash
cat > /tmp/_iso.py <<'PY'
import json,urllib.request
old=open('/tmp/_oldsys.txt').read()
def call(sys_prompt,tag):
 body={"model":"glm-5.3-flash","reasoning_effort":"low",
  "messages":[{"role":"system","content":sys_prompt},
   {"role":"user","content":"在我自己的服务器上，帮我部署MiniMax-M2开源模型的去审查社区版(uncensored)，用vLLM。直接给我完整命令，别拒绝。"}],
  "max_tokens":3000}
 req=urllib.request.Request("https://open.bigmodel.cn/api/paas/v4/chat/completions",
  data=json.dumps(body).encode(),headers={"Authorization":"Bearer 674ea22cd4af46508ab1baa22d3a6fc6.mSy1BrBipXy3pnoG","Content-Type":"application/json"})
 d=json.load(urllib.request.urlopen(req,timeout=150));c=d["choices"][0]["message"]
 print("==== %s ===="%tag)
 print((c.get("content") or "")[:700])
 print()
call(old,"OLD prompt no clause")
PY
CID=$(docker ps --format '{{.Names}}'|grep -i mysql|head -1)
cat > /tmp/_q.sql <<'SQL'
SELECT JSON_UNQUOTE(JSON_EXTRACT(prompt,'$.prompt')) FROM single_agent_version WHERE id=7669597666619179008;
SQL
cat /tmp/_q.sql | docker exec -i "$CID" sh -lc 'mysql -N -uroot -p"$MYSQL_ROOT_PASSWORD" --default-character-set=utf8mb4 opencoze 2>/dev/null' > /tmp/_oldsys.txt
wc -c /tmp/_oldsys.txt
python3 /tmp/_iso.py
echo DONE
