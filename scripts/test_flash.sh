#!/bin/bash
KEY=674ea22cd4af46508ab1baa22d3a6fc6.mSy1BrBipXy3pnoG
URL=https://open.bigmodel.cn/api/paas/v4
test_level(){
  local tag="$1"; local body="$2"
  curl -s "$URL/chat/completions" -H "Authorization: Bearer $KEY" -H 'Content-Type: application/json' -d "$body" > /tmp/f_$tag.json 2>&1
  python3 - "$tag" <<'PY'
import json,sys
tag=sys.argv[1]
try:
    d=json.load(open(f"/tmp/f_{tag}.json"))
    if "error" in d: print(f"{tag:14} -> 报错 {json.dumps(d['error'],ensure_ascii=False)[:120]}"); raise SystemExit
    m=d["choices"][0]["message"]
    rc=(m.get("reasoning_content") or "").strip()
    print(f"{tag:14} -> 答案={ (m.get('content') or '').strip()[:8]:8} 思考长度={len(rc)}")
except SystemExit: raise
except Exception as e: print(f"{tag:14} -> 解析失败 {e}: {open(f'/tmp/f_{tag}.json').read()[:150]}")
PY
}
Q='9.11和9.9哪个大？只回答数字。'
for lv in low medium high; do
  test_level "effort_$lv" "{\"model\":\"glm-5.3-flash\",\"reasoning_effort\":\"$lv\",\"messages\":[{\"role\":\"user\",\"content\":\"$Q\"}],\"max_tokens\":2048}"
done
# thinking 对象写法（智谱原生）
test_level "think_enabled" "{\"model\":\"glm-5.3-flash\",\"thinking\":{\"type\":\"enabled\"},\"messages\":[{\"role\":\"user\",\"content\":\"$Q\"}],\"max_tokens\":2048}"
# 不带任何思考参数（看默认）
test_level "default" "{\"model\":\"glm-5.3-flash\",\"messages\":[{\"role\":\"user\",\"content\":\"$Q\"}],\"max_tokens\":2048}"
echo "[DONE]"
