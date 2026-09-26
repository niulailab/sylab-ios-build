#!/bin/bash
python3 - <<'PY'
J="/tmp/ipachk2/ex/Payload/sylab.app/main.jsbundle"
txt=open(J,"rb").read().decode("utf-8","ignore")
i=txt.find("renderStyledContent")
print("=== context around renderStyledContent (-100,+600) ===")
print(txt[i-100:i+600])
PY