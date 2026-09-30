#!/bin/bash
echo "===== 从现有容器捕获环境变量(不打印明文) ====="
getenv(){ docker inspect tool-proxy --format "{{range .Config.Env}}{{println .}}{{end}}" | grep "^$1=" | head -1 | cut -d= -f2-; }
OLD_GT=$(getenv GITHUB_TOKEN)
OLD_BK=$(getenv BOCHA_API_KEY)
OLD_AK=$(getenv MINIO_AK)
OLD_SK=$(getenv MINIO_SK)
# 旧容器无博查/minio_sk时，从 compose .env 兜底
cd /root/coze-studio/docker || exit 1
set -a; [ -f .env ] && . ./.env; set +a
[ -z "$OLD_BK" ] && OLD_BK=sk-ce584c9409724606a906e8147bcf71a1
[ -z "$OLD_AK" ] && OLD_AK=${MINIO_ROOT_USER}
[ -z "$OLD_SK" ] && OLD_SK=${MINIO_ROOT_PASSWORD}
[ -z "$OLD_GT" ] && OLD_GT=${GITHUB_TOKEN}
echo "captured: GT_len=${#OLD_GT} BK_len=${#OLD_BK} AK_len=${#OLD_AK} SK_len=${#OLD_SK}"
[ ${#OLD_GT} -lt 10 ] && { echo FATAL_GT; exit 9; }
[ ${#OLD_SK} -lt 3 ] && { echo FATAL_SK; exit 9; }

echo "===== 前置核对 ====="
docker network ls | grep coze-network | head -2
for d in /root/coze-studio/tool-proxy/server.py /root/coze-studio/tool-proxy/bot_creator.py /root/flutter-sdk /root/android-sdk /root/xiaosu-flutter-repo /root/gradle-cache /usr/local/go /root/user-projects; do
 printf "%-55s" "$d"; [ -e "$d" ] && echo OK || echo MISSING
done

echo "===== 重建 tool-proxy ====="
docker stop tool-proxy && docker rm tool-proxy
docker run -d --name tool-proxy --restart unless-stopped \
 --network coze-network -p 9092:9092 \
 -e MINIO_AK="$OLD_AK" -e MINIO_SK="$OLD_SK" \
 -e MINIO_ENDPOINT=http://coze-minio:9000 \
 -e GITHUB_TOKEN="$OLD_GT" \
 -e BOCHA_API_KEY="$OLD_BK" \
 -v /root/coze-studio/tool-proxy/server.py:/app/server.py:ro \
 -v /root/coze-studio/tool-proxy/bot_creator.py:/app/bot_creator.py:ro \
 -v /root/flutter-sdk:/root/flutter-sdk:rw \
 -v /root/android-sdk:/root/android-sdk:rw \
 -v /root/xiaosu-flutter-repo:/root/xiaosu-flutter-repo:rw \
 -v /root/gradle-cache:/root/.gradle:rw \
 -v /usr/local/go:/usr/local/go:ro \
 -v /root/user-projects:/root/user-projects:ro \
 tool-proxy:1.3-filepath
sleep 14
docker inspect tool-proxy --format 'created={{.Created}} status={{.State.Status}} image={{.Config.Image}}'
docker exec tool-proxy printenv BOCHA_API_KEY | awk '{print "BOCHA in container len="length($0)}'
echo "[DONE]"
