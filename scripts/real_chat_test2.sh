#!/bin/bash
PAT="pat_fb5f8dccaaf858b78152bff3788686c76a46a4bfe95736eb94441da0d40e6ed4"
BASE="https://direct.symsgf.xyz:8099"
H=(-H "Authorization: Bearer $PAT" -H "Content-Type: application/json" -H "Host: direct.symsgf.xyz")
CID=$(cat /tmp/_cid)
echo "chat=$CID"
echo "--- GET retrieve raw ---"
curl -sk -m 30 "$BASE/v3/chat/retrieve?chat_id=$CID" "${H[@]}" | head -c 400
echo
echo "--- POST retrieve ---"
curl -sk -m 60 -X POST "$BASE/v3/chat/retrieve" "${H[@]}" --data "{\"chat_id\":\"$CID\"}" | head -c 3000
echo
echo "--- message list ---"
curl -sk -m 30 -X POST "$BASE/v3/chat/message/list" "${H[@]}" --data "{\"chat_id\":\"$CID\"}" | head -c 3000
echo
echo DONE
