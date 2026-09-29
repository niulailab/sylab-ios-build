#!/bin/bash
KEY=674ea22cd4af46508ab1baa22d3a6fc6.mSy1BrBipXy3pnoG
URL=https://open.bigmodel.cn/api/paas/v4
Q='我需要把一张参考图生成5秒动态视频。你手上有这些工具：video_generate(图生视频)、run_command(执行shell)、web_search。请逐步分析你会怎么做、先调哪个工具、为什么，不要真的调用。'
test_level(){
  local tag="$1"; local body="$2"
  curl -s "$URL/chat/completions" -H "Authorization: Bearer $KEY" -H 'Content-Type: application/json' -d "$body" > /tmp/g_$tag.json 2>&1
  python3 - "$tag" <<'PY'
import json,sys
tag=sys.argv[1]
try:
    d=json.load(open(f"/tmp/g_{tag}.json"))
    if "error" in d: print(f"{tag:10} -> 报错 {json.dumps(d['error'],ensure_ascii=False)[:90]}"); raise SystemExit
    m=d["choices"][0]["message"]
    rc=(m.get("reasoning_content") or "").strip()
    c=(m.get("content") or "").strip()
    hits=[t for t in ["video_generate","run_command","web_search"] if t in c]
    print(f"{tag:10} -> 思考长度={len(rc):4}  正文中提到工具={hits}")
except SystemExit: raise
except Exception as e: print(f"{tag:10} -> 失败 {e}")
PY
}
for lv in low high max; do
  python3 - "$lv" > /tmp/body_$lv.json <<'PY'
import json,sys
lv=sys.argv[1]
q='我需要把一张参考图生成5秒动态视频。你手上有这些工具：video_generate(图生视频)、run_command(执行shell)、web_search。请逐步分析你会怎么做、先调哪个工具、为什么，不要真的调用。'
print(json.dumps({"model":"glm-5.3-flash","reasoning_effort":lv,
  "messages":[{"role":"user","content":"$q"}],"max_tokens":3000},ensure_ascii=False))
PY
  body=$(cat /tmp/body_$lv.json | sed 's/\$q/PLACEHOLDER/')
done
# 直接用 python 构造请求更稳
python3 - <<'PY'
import json,urllib.request
KEY="674ea22cd4af46508ab1baa22d3a6fc6.mSy1BrBipXy3pnoG"
URL="https://open.bigmodel.cn/api/paas/v4/chat/completions"
q='我需要把一张参考图生成5秒动态视频。你手上有这些工具：video_generate(图生视频)、run_command(执行shell)、web_search。请逐步分析你会怎么做、先调哪个工具、为什么，不要真的调用。'
for lv in ["low","high","max"]:
    body=json.dumps({"model":"glm-5.3-flash","reasoning_effort":lv,
        "messages":[{"role":"user","content":q}],"max_tokens":3000}).encode()
    req=urllib.request.Request(URL,data=body,headers={"Authorization":f"Bearer {KEY}","Content-Type":"application/json"})
    try:
        d=json.load(urllib.request.urlopen(req,timeout=120))
        m=d["choices"][0]["message"]
        rc=(m.get("reasoning_content") or "").strip(); c=(m.get("content") or "").strip()
        hits=[t for t in ["video_generate","run_command","web_search"] if t in c]
        print(f"{lv:5} -> 思考长度={len(rc):4} 正文工具={hits}")
    except Exception as e:
        print(lv,"失败",e)
PY
echo "[DONE]"
