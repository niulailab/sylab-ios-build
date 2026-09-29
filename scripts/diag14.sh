#!/bin/bash
MP=$(docker exec coze-mysql printenv MYSQL_ROOT_PASSWORD)
M(){ docker exec coze-mysql mysql -uroot -p"$MP" opencoze -e "$1" 2>/dev/null; }

echo "### 1. ModelStyle 完整枚举 ###"
grep -n "ModelStyle" /root/coze-studio/backend/api/model/app/bot_common/bot_common.go | head -15

echo ""
echo "### 2. model_meta.json 里 100015 ###"
python3 -c "
import json
d=json.load(open('/root/coze-studio/backend/conf/model/model_meta.json'))
items = d if isinstance(d,list) else d.get('data',d.get('models',[]))
if isinstance(items,dict): items=list(items.values())
for m in items:
    if isinstance(m,dict) and str(m.get('id',m.get('model_id','')))=='100015':
        print(json.dumps(m,ensure_ascii=False)[:500])
" 2>&1 | head
echo "--- fallback: grep ---"
grep -A3 '"100015"' /root/coze-studio/backend/conf/model/model_meta.json 2>/dev/null | head -12

echo ""
echo "### 3. DB model_entity 100015 ###"
M "SELECT * FROM model_entity WHERE id=100015 OR model_id='100015'\G" 2>&1 | head -25

echo "[DONE]"
