#!/usr/bin/env bash
set +e
TS=$(date +%Y%m%d%H%M%S)
TARGET=/etc/nginx/sites-enabled/default
NEWCONF=/tmp/_extra
echo "######## A. new conf present ########"
if [ ! -s "$NEWCONF" ];then echo "no extra conf uploaded, abort"; exit 1; fi
echo "downloaded bytes: $(wc -c < "$NEWCONF")"
echo
echo "######## B. sanity: contains skill-api ########"
grep -q "location /skill-api/" "$NEWCONF" && echo "skill-api block present" || { echo "MISSING skill-api, abort"; exit 1; }
echo
echo "######## C. backup current conf ########"
cp -a "$TARGET" "/etc/nginx/sites-enabled/default.bak_skillapi_$TS"
echo "backup: /etc/nginx/sites-enabled/default.bak_skillapi_$TS"
echo
echo "######## D. stage + nginx -t ########"
cp "$NEWCONF" "$TARGET"
if nginx -t;then
 echo "nginx -t OK -> reload"
 systemctl reload nginx || nginx -s reload
 echo "reloaded"
else
 echo "nginx -t FAILED -> rollback"
 cp -a "/etc/nginx/sites-enabled/default.bak_skillapi_$TS" "$TARGET"
 nginx -t && systemctl reload nginx
 echo "rolled back"; exit 1
fi
echo
echo "######## E. verify skill-api health via public 8099 ########"
curl -s "https://direct.symsgf.xyz:8099/skill-api/health" -k | head -c 300
echo
echo "######## F. verify skill-api memory search ########"
curl -s -X POST "https://direct.symsgf.xyz:8099/skill-api/memory/search" -k \
 -H 'Content-Type: application/json' \
 -d '{"agent_id":"sylab-ai","query":"x","limit":1}' | head -c 300
echo
echo "DEPLOY_SKILLAPI_DONE"
