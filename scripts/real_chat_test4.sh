#!/bin/bash
PAT="pat_fb5f8dccaaf858b78152bff3788686c76a46a4bfe95736eb94441da0d40e6ed4"
BASE="https://direct.symsgf.xyz:8099"
H=(-H "Authorization: Bearer $PAT" -H "Content-Type: application/json" -H "Host: direct.symsgf.xyz")
CID="7690279208961966080"; CONV="7690279208899051520"
echo "--- full retrieve ---"
curl -sk -m 30 "$BASE/v3/chat/retrieve?chat_id=$CID&conversation_id=$CONV" "${H[@]}" > /tmp/_full.json
python3 -c "import json;print(json.dumps(json.load(open('/tmp/_full.json')),ensure_ascii=False,indent=1)[:3500])"
echo "--- message list GET ---"
curl -sk -m 30 "$BASE/v3/chat/message/list?conversation_id=$CONV&chat_id=$CID" "${H[@]}" | head -c 3000
echo DONE
