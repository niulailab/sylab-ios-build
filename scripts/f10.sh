#!/bin/bash
echo "===== 网络全名 ====="
docker network ls | grep coze | awk '{print NR": ["$2"]"}'
NET=$(docker network ls --format '{{.Name}}' | grep -E "coze-network$|_coze-network$" | head -1)
echo "USE NET=$NET"
docker rm -f tool-proxy 2>/dev/null

cd /root/coze-studio/docker || exit 1
set -a; . ./.env; set +a
GT=${GITHUB_TOKEN}
BK=sk-ce584c9409724606a906e8147bcf71a1
AK=${MINIO_ROOT_USER}; SK=${MINIO_ROOT_PASSWORD}
echo "GT_len=${#GT} AK_len=${#AK} SK_len=${#SK}"
[ ${#GT} -lt 10 ] && { echo FATAL_GT; exit 9; }

docker run -d --name tool-proxy --restart unless-stopped \
 --network "$NET" -p 9092:9092 \
 -e MINIO_AK="$AK" -e MINIO_SK="$SK" \
 -e MINIO_ENDPOINT=http://coze-minio:9000 \
 -e GITHUB_TOKEN="$GT" -e BOCHA_API_KEY="$BK" \
 -v /root/coze-studio/tool-proxy/server.py:/app/server.py:ro \
 -v /root/coze-studio/tool-proxy/bot_creator.py:/app/bot_creator.py:ro \
 -v /root/flutter-sdk:/root/flutter-sdk:rw \
 -v /root/android-sdk:/root/android-sdk:rw \
 -v /root/xiaosu-flutter-repo:/root/xiaosu-flutter-repo:rw \
 -v /root/gradle-cache:/root/.gradle:rw \
 -v /usr/local/go:/usr/local/go:ro \
 -v /root/user-projects:/root/user-projects:ro \
 tool-proxy:1.3-filepath
sleep 15
docker inspect tool-proxy --format 'status={{.State.Status}} image={{.Config.Image}}'
docker exec tool-proxy printenv BOCHA_API_KEY 2>/dev/null | awk '{print "BOCHA len="length($0)}'
echo "[DONE]"
