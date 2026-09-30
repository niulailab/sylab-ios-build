#!/bin/bash
NET=coze-studio_coze-network
docker rm -f tool-proxy 2>/dev/null
docker run -d --name tool-proxy --restart unless-stopped \
 --network "$NET" -p 9092:9092 \
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
docker exec tool-proxy sh -c 'echo GT_len=${#GITHUB_TOKEN} BK_len=${#BOCHA_API_KEY} AK_len=${#MINIO_AK} SK_len=${#MINIO_SK}'
echo "[DONE]"
