#!/bin/bash
set -e
MP=$(docker exec coze-mysql printenv MYSQL_ROOT_PASSWORD)
BK=/root/backup_model100015_$(date +%Y%m%d_%H%M%S)
mkdir -p "$BK"
docker exec coze-mysql mysqldump -uroot -p"$MP" opencoze model_instance > "$BK/model_instance.sql" 2>/dev/null
echo "备份: $BK/model_instance.sql"
docker exec coze-mysql mysql -uroot -p"$MP" opencoze -N -e "SELECT connection FROM model_instance WHERE id=100015;" 2>/dev/null > "$BK/conn_100015.before.json"
docker exec coze-mysql mysql -uroot -p"$MP" opencoze -N -e "SELECT capability FROM model_instance WHERE id=100015;" 2>/dev/null > "$BK/cap_100015.before.json"
echo "--- 修改前 connection ---"; cat "$BK/conn_100015.before.json"

python3 - <<'PY'
import json, subprocess
key="674ea22cd4af46508ab1baa22d3a6fc6.mSy1BrBipXy3pnoG"
url="https://open.bigmodel.cn/api/paas/v4"
conn={"openai":{"model":"glm-5.3","api_key":key,"base_url":url},
      "base_conn_info":{"model":"glm-5.3","api_key":key,"base_url":url,"thinking_type":1}}
cap={"cot_display":True,"function_call":True,"audio_understanding":False,
     "image_understanding":True,"support_multi_modal":True,"video_understanding":False}
def esc(s): return s.replace("\\","\\\\").replace('"','\\"')
open("/tmp/new_conn.json","w").write(json.dumps(conn,ensure_ascii=False))
open("/tmp/new_cap.json","w").write(json.dumps(cap,ensure_ascii=False))
PY
docker cp /tmp/new_conn.json coze-mysql:/tmp/new_conn.json
docker cp /tmp/new_cap.json coze-mysql:/tmp/new_cap.json

NC=$(docker exec coze-mysql cat /tmp/new_conn.json)
NP=$(docker exec coze-mysql cat /tmp/new_cap.json)
docker exec coze-mysql mysql -uroot -p"$MP" opencoze -e "UPDATE model_instance SET connection='$NC', capability='$NP' WHERE id=100015;"
echo "--- 修改后 connection ---"
docker exec coze-mysql mysql -uroot -p"$MP" opencoze -N -e "SELECT connection FROM model_instance WHERE id=100015;" 2>/dev/null
echo "--- 修改后 capability ---"
docker exec coze-mysql mysql -uroot -p"$MP" opencoze -N -e "SELECT capability FROM model_instance WHERE id=100015;" 2>/dev/null
echo "[DONE]"
