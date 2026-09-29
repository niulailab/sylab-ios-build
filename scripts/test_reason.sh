#!/bin/bash
MP=$(docker exec coze-mysql printenv MYSQL_ROOT_PASSWORD)
echo "### 从DB读取100015当前配置并发请求验证思考 ###"
docker exec coze-mysql mysql -uroot -p"$MP" opencoze -N -e "SELECT connection FROM model_instance WHERE id=100015;" 2>/dev/null > /tmp/c15.json
python3 - <<'PY'
import json
c=json.load(open("/tmp/c15.json"))
b=c["base_conn_info"]
open("/tmp/key15","w").write(b["api_key"])
open("/tmp/url15","w").write(b["base_url"])
open("/tmp/model15","w").write(b["model"])
print("model=",b["model"],"url=",b["base_url"],"thinking_type=",b.get("thinking_type"))
PY
KEY=$(cat /tmp/key15); URL=$(cat /tmp/url15); MODEL=$(cat /tmp/model15)
echo "### 请求1: 纯问答，看 reasoning_content ###"
curl -s "$URL/chat/completions" -H "Authorization: Bearer $KEY" -H 'Content-Type: application/json' \
 -d "{\"model\":\"$MODEL\",\"messages\":[{\"role\":\"user\",\"content\":\"9.11和9.9哪个大？只回答数字。\"}],\"max_tokens\":2048}" \
 > /tmp/r1.json 2>&1
python3 - <<'PY'
import json
try:
    d=json.load(open("/tmp/r1.json"))
    if "error" in d: print("上游报错:",json.dumps(d["error"],ensure_ascii=False)); raise SystemExit
    m=d["choices"][0]["message"]
    rc=(m.get("reasoning_content") or "").strip()
    print("content:",(m.get("content") or "").strip()[:100])
    print("reasoning_content 长度:",len(rc))
    print("reasoning 预览:",rc[:200].replace("\n"," "))
    print("==> 思考已恢复" if rc else "==> 思考仍为空")
except SystemExit: raise
except Exception as e:
    print("解析失败:",e); print(open("/tmp/r1.json").read()[:500])
PY
echo "[DONE]"
