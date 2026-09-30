#!/bin/bash
cd /root/coze-studio/docker || exit 1
echo "===== .env 是否存在 + 键名(仅key) ====="
[ -f .env ] && grep -vE '^\s*#|^\s*$' .env | cut -d= -f1 | sort
echo ""
echo "===== 找其它 env 文件 ====="
ls -la .env* 2>/dev/null
find /root/coze-studio -maxdepth 2 -name ".env*" -o -maxdepth 2 -name "*.env" 2>/dev/null | head
echo ""
echo "===== 旧镜像内是否烤了默认env ====="
docker image inspect tool-proxy:1.3-filepath --format '{{range .Config.Env}}{{println .}}{{end}}' | grep -iE "MINIO|GITHUB|BOCHA" | sed -E 's/=(.{4}).*/=\1****/'
echo "[DONE]"
