#!/bin/bash
python3 - <<'PY'
J="/tmp/ipachk2/ex/Payload/sylab.app/main.jsbundle"
data=open(J,"rb").read()
print("bundle bytes:",len(data))
# count CJK chars when decoded utf-8 (ignore errors)
txt=data.decode("utf-8","ignore")
cjk=sum(1 for ch in txt if '\u4e00'<=ch<='\u9fff')
print("CJK chars in bundle:",cjk)
for s in ["浏览器","普通网页","绝不跳外部浏览器","文件卡片","renderStyledContent",
          "setMdPreviewUrl","FIX link-in-bold","openExternally","2563eb"]:
    print(f"  [{txt.count(s)}] {s}")
# Is it Hermes? look for magic
print("Hermes magic present:", b"\x1f\x19" in data[:8] or "Hermes" in txt[:2000])
PY