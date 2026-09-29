#!/bin/bash
echo "===== 博查密钥配置状态(不泄露全值) ====="
BK=$(docker exec tool-proxy printenv BOCHA_API_KEY 2>/dev/null)
if [ -z "$BK" ]; then echo "BOCHA_API_KEY 环境变量: 未设置(空)"; else echo "已设置 长度=${#BK} 前缀=${BK:0:4}"; fi
echo ""
echo "===== 实测 POST /search ====="
curl -s -X POST http://127.0.0.1:9092/search -H 'Content-Type: application/json' \
 -d '{"query":"GPT-6 OpenAI 发布","count":6}' -o /tmp/s1.json
python3 - <<'PY'
import json
d=json.load(open("/tmp/s1.json"))
if isinstance(d,dict):
    print("source =",d.get("source"))
    print("bocha_error =",d.get("bocha_error"))
    r=d.get("results") or d.get("data") or []
    print("结果条数 =",len(r) if isinstance(r,list) else r)
    for it in (r[:3] if isinstance(r,list) else []):
        print("   -",(it.get("title") or "")[:60])
else: print("非dict:",str(d)[:200])
PY
echo ""
echo "===== 实测 web_search对应别名 /v1/web-search ====="
curl -s -X POST http://127.0.0.1:9092/v1/web-search -H 'Content-Type: application/json' \
 -d '{"query":"今天 科技新闻","count":4}' -o /tmp/s2.json
python3 -c "import json;d=json.load(open('/tmp/s2.json'));print('source=',d.get('source') if isinstance(d,dict) else d,'结果=',len(d.get('results',[])) if isinstance(d,dict) else '')"
echo ""
echo "===== tool-proxy 最近日志中 bocha/fallback 痕迹 ====="
docker logs tool-proxy --since 3m 2>&1 | grep -iE "bocha|360|fallback|search" | tail -10
echo "[DONE]"
