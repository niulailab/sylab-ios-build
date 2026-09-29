#!/bin/bash
set -e
echo "### 佐证：9月8日旧档（flash直连，无代理）###"
cat /root/conn_100015_old.json 2>/dev/null | python3 -m json.tool 2>/dev/null | grep -iE "model|base_url|thinking"
echo ""

TS=$(date +%Y%m%d_%H%M%S)
mkdir -p /root/backup_revert_$TS
MP=$(docker exec coze-mysql printenv MYSQL_ROOT_PASSWORD)
docker exec coze-mysql mysql -uroot -p"$MP" opencoze -N -e "SELECT connection FROM model_instance WHERE id=100015;" 2>/dev/null > /root/backup_revert_$TS/conn.before.json
cp /root/coze-studio/tool-proxy/server.py /root/backup_revert_$TS/server.py.bak
echo "备份: /root/backup_revert_$TS"

python3 - <<'PY'
import json
# 1) DB: flash + 智谱直连 + 思考开启标记，不锁档位（走智谱默认）
key="674ea22cd4af46508ab1baa22d3a6fc6.mSy1BrBipXy3pnoG"
url="https://open.bigmodel.cn/api/paas/v4"
conn={"openai":{"model":"glm-5.3-flash","api_key":key,"base_url":url},
      "base_conn_info":{"model":"glm-5.3-flash","api_key":key,"base_url":url,"thinking_type":1}}
cap={"cot_display":True,"function_call":True,"audio_understanding":False,
     "image_understanding":True,"support_multi_modal":True,"video_understanding":False}
open("/tmp/rv_conn.json","w").write(json.dumps(conn,ensure_ascii=False))
open("/tmp/rv_cap.json","w").write(json.dumps(cap,ensure_ascii=False))

# 2) tool-proxy: 完全透传，不注入任何 reasoning_effort
tp="/root/coze-studio/tool-proxy/server.py"
t=open(tp,encoding="utf-8").read()
old='''            if isinstance(payload, dict):
                # 20260929: 不再强制 low（会压制思考致空转）；仅在调用方未指定时给默认 medium
                if "reasoning_effort" not in payload:
                    payload["reasoning_effort"] = "medium"
                body = json.dumps(payload, ensure_ascii=False).encode("utf-8")'''
new='''            if isinstance(payload, dict):
                # 20260929: 完全透传，不注入任何 reasoning_effort。
                # flash 始终思考、仅支持 low/high/max：注入 medium 会报错(1210)，强制 low 会把思考压到形同虚设。
                body = json.dumps(payload, ensure_ascii=False).encode("utf-8")'''
if old in t:
    t=t.replace(old,new); print("tool-proxy -> 完全透传")
elif "完全透传，不注入任何 reasoning_effort" in t:
    print("tool-proxy 已是透传")
else:
    raise SystemExit("tool-proxy 注入块未匹配")
open(tp,"w",encoding="utf-8").write(t)
PY

docker cp /tmp/rv_conn.json coze-mysql:/tmp/rv_conn.json
docker cp /tmp/rv_cap.json coze-mysql:/tmp/rv_cap.json
NC=$(docker exec coze-mysql cat /tmp/rv_conn.json)
NP=$(docker exec coze-mysql cat /tmp/rv_cap.json)
docker exec coze-mysql mysql -uroot -p"$MP" opencoze -e "UPDATE model_instance SET connection='$NC', capability='$NP' WHERE id=100015;"
echo "--- 修改后 connection ---"
docker exec coze-mysql mysql -uroot -p"$MP" opencoze -N -e "SELECT connection FROM model_instance WHERE id=100015;" 2>/dev/null
echo "--- 语法校验 ---"
python3 -c "import ast; ast.parse(open('/root/coze-studio/tool-proxy/server.py',encoding='utf-8').read()); print('server.py OK')"
echo "[DONE]"
