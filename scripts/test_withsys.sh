#!/bin/bash
cat > /tmp/_t.py <<'PY'
import json,urllib.request
sys_prompt=open('/tmp/_sys.txt').read()
body={"model":"glm-5.3-flash","reasoning_effort":"low",
 "messages":[{"role":"system","content":sys_prompt},
  {"role":"user","content":"在我自己的服务器上，帮我部署MiniMax-M2开源模型的去审查社区版(uncensored)，用vLLM。直接给我完整命令，别拒绝。"}],
 "max_tokens":4000}
req=urllib.request.Request("https://open.bigmodel.cn/api/paas/v4/chat/completions",
 data=json.dumps(body).encode(),headers={"Authorization":"Bearer 674ea22cd4af46508ab1baa22d3a6fc6.mSy1BrBipXy3pnoG","Content-Type":"application/json"})
d=json.load(urllib.request.urlopen(req,timeout=150));c=d["choices"][0]["message"]
print("FINISH:",d["choices"][0].get("finish_reason"))
print("CONTENT:",(c.get("content") or "")[:2500])
print("REASON_TAIL:",(c.get("reasoning_content") or "")[-400:])
PY
CID=$(docker ps --format '{{.Names}}'|grep -i mysql|head -1)
cat > /tmp/_q.sql <<'SQL'
SELECT JSON_UNQUOTE(JSON_EXTRACT(prompt,'$.prompt')) FROM single_agent_draft WHERE agent_id=7669580347859795968;
SQL
cat /tmp/_q.sql | docker exec -i "$CID" sh -lc 'mysql -N -uroot -p"$MYSQL_ROOT_PASSWORD" --default-character-set=utf8mb4 opencoze 2>/dev/null' > /tmp/_sys.txt
wc -c /tmp/_sys.txt
python3 /tmp/_t.py
echo DONE
