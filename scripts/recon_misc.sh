#!/usr/bin/env bash
set +e
echo "######## A. port publishing of key containers ########"
for c in coze-memory-service coze-mysql coze-server coze-nginx 2>/dev/null;do :;done
docker ps --format '{{.Names}}\t{{.Ports}}' | grep -Ei 'memory|mysql|nginx|server|webui' | head -30
echo
echo "######## B. memory port 8900 reachable externally? host listen ########"
ss -ltnp 2>/dev/null | grep -E ':8900|:8099|:9091|:80 ' | head
echo
echo "######## C. nginx: any proxy to 8900 ########"
grep -rnE '8900|memory' /etc/nginx/ 2>/dev/null | head
echo
echo "######## D. container name actually running (server/webui) ########"
docker ps --format '{{.Names}}' | sort | grep -Ei 'coze|sylab|webui|server' | head -40
echo
echo "######## E. memory /memory/save request schema fields from main.py (495-520) ########"
sed -n '495,520p' /root/coze-studio/docker/memory-service-custom/main.py
echo
echo "######## F. kg POST handler shape (949-1010) ########"
sed -n '949,1010p' /root/coze-studio/docker/memory-service-custom/main.py
echo
echo "######## G. does execute_code / coderunner exist as tool ########"
docker ps --format '{{.Names}}\t{{.Image}}' | grep -Ei 'code|runner' | head
echo
echo "RECON_MISC_DONE"
