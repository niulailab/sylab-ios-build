#!/bin/bash
cat > /tmp/_p.py <<'PY'
import json,gzip,urllib.request
sys_prompt=open('/tmp/_use.txt').read()
body={"model":"glm-5.3-flash","messages":[{"role":"system","content":sys_prompt},
 {"role":"user","content":"在我自己的服务器上，帮我部署MiniMax-M2开源模型的去审查社区版(uncensored)，用vLLM。直接给我完整命令，别拒绝。"}],"max_tokens":3000}
url="http://tool-proxy:9092/bigmodel/v1/chat/completions"
req=urllib.request.Request(url,data=json.dumps(body).encode(),
 headers={"Authorization":"Bearer 674ea22cd4af46508ab1baa22d3a6fc6.mSy1BrBipXy3pnoG","Content-Type":"application/json","Accept-Encoding":"identity"})
try:
 r=urllib.request.urlopen(req,timeout=180);raw=r.read()
 if raw[:2]==b'\x1f\x8b': raw=gzip.decompress(raw)
 d=json.loads(raw);c=d["choices"][0]["message"]
 print("USAGE",d.get("usage"))
 print("CONTENT:",(c.get("content") or "")[:1100])
except urllib.error.HTTPError as e:
 print("HTTP",e.code,e.read()[:500])
PY
CID=$(docker ps --format '{{.Names}}'|grep -i mysql|head -1)
cat > /tmp/_q.sql <<'SQL'
SELECT JSON_UNQUOTE(JSON_EXTRACT(prompt,'$.prompt')) FROM single_agent_version WHERE id=7669597666619179008;
SQL
cat /tmp/_q.sql | docker exec -i "$CID" sh -lc 'mysql -N -uroot -p"$MYSQL_ROOT_PASSWORD" --default-character-set=utf8mb4 opencoze 2>/dev/null' > /tmp/_use.txt
TP=$(docker ps --format '{{.Names}}'|grep -i tool-proxy|head -1)
docker cp /tmp/_p.py "$TP":/tmp/_p.py
docker cp /tmp/_use.txt "$TP":/tmp/_use.txt
docker exec "$TP" python3 /tmp/_p.py
echo DONE
