#!/bin/bash
echo "=== restart tool-proxy ==="
docker restart tool-proxy
sleep 12
echo "=== /schedule/health ==="
curl -s -m 10 http://127.0.0.1:9092/schedule/health
echo ""
echo "=== 直连9092伪造header(公网特征通过curl来自外部?此curl源自docker host->容器视为172.17/18) ==="
echo "--- A) 无任何凭证,期望拒绝 ---"
docker exec tool-proxy python -c "
import urllib.request,json
req=urllib.request.Request('http://127.0.0.1:9092/schedule/list',data=b'{}',headers={'Content-Type':'application/json'})
print(urllib.request.urlopen(req).read().decode()[:200])
"
echo ""
echo "--- B) 带真实session_key(owner) scope=all,期望2任务 ---"
SK=$(docker exec coze-mysql mysql -uroot -pd3G8JG273iE8C4irRWJX opencoze -N -e "select session_key from user where id=7666848996043784192;" 2>/dev/null)
curl -s -m 10 -X POST http://127.0.0.1:9092/schedule/list \
 -H "Content-Type: application/json" -H "x-session-key: $SK" -d '{"scope":"all"}'
echo ""
echo "=== startup logs (scheduler started) ==="
docker logs tool-proxy --tail 20 2>&1 | grep -iE "scheduler|error|watch" | tail
