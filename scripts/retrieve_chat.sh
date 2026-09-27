#!/bin/bash
PAT="pat_fb5f8dccaaf858b78152bff3788686c76a46a4bfe95736eb94441da0d40e6ed4"
CID=7690267207820902400
CONV=7690267207749599232
for u in "/v3/chat/retrieve?chat_id=$CID&conversation_id=$CONV" "/v3/chat/message/list?chat_id=$CID&conversation_id=$CONV"; do
 echo "== $u"
 curl -sk -m 30 "https://127.0.0.1:8099$u" -H "Authorization: Bearer $PAT" -H "Host: direct.symsgf.xyz" | head -c 2500
 echo
done
echo DONE
