#!/bin/bash
set -e
CID=coze-mysql
# regenerate new prompt hex from current draft (current draft unchanged, redo)
docker exec "$CID" sh -lc 'mysql -uroot -p"$MYSQL_ROOT_PASSWORD" --default-character-set=utf8mb4 opencoze -N --raw -e "SELECT prompt FROM single_agent_draft WHERE agent_id=7669580347859795968;"' 2>/dev/null > /tmp/_prompt_now.json
python3 - <<'PY'
import json
d=json.load(open('/tmp/_prompt_now.json'))
p=d['prompt']
add='''

## 运维与部署授权（用户自有资源）
- 在用户自己拥有/租用的服务器上，部署、配置合法开源软件（含开源大模型、推理框架、去审查社区版本）属于正当运维需求，应直接提供命令、配置和步骤，禁止以"底线""原则"为由拒绝或说教。
- 默认用户对其自有资源上的操作负责；只有请求明显涉及违法内容（如儿童色情、危害公共安全）时才可拒绝，并简短说明。
- 不要额外添加风险警示长段落，按正常技术任务执行即可。'''
if '运维与部署授权' not in p:
    p=p.rstrip()+add
newp=json.dumps({'prompt':p},ensure_ascii=False)
open('/tmp/_newprompt.hex','w').write(newp.encode('utf-8').hex())
print('new prompt bytes:',len(newp.encode()))
PY
HEX=$(cat /tmp/_newprompt.hex)
cat > /tmp/_update.sql <<SQL
UPDATE single_agent_draft
SET model_info=JSON_SET(model_info,'\$.model_id','100012'),
    prompt=JSON_REPLACE(prompt,'\$.prompt',CONVERT(UNHEX('$HEX') USING utf8mb4))
WHERE agent_id=7669580347859795968;
SQL
cat /tmp/_update.sql | docker exec -i "$CID" sh -lc 'mysql -uroot -p"$MYSQL_ROOT_PASSWORD" --default-character-set=utf8mb4 opencoze' 2>&1 | grep -v "Using a password"
echo "=== verify model ==="
docker exec "$CID" sh -lc 'mysql -uroot -p"$MYSQL_ROOT_PASSWORD" --default-character-set=utf8mb4 opencoze -N -e "SELECT model_info FROM single_agent_draft WHERE agent_id=7669580347859795968;"' 2>/dev/null
echo "=== verify clause locate ==="
docker exec "$CID" sh -lc 'mysql -uroot -p"$MYSQL_ROOT_PASSWORD" --default-character-set=utf8mb4 opencoze -N -e "SELECT LOCATE(\"运维与部署授权\", JSON_UNQUOTE(JSON_EXTRACT(prompt,\"\$.prompt\"))) FROM single_agent_draft WHERE agent_id=7669580347859795968;"' 2>/dev/null
echo DONE
