#!/bin/bash
echo "=== 1) 从 tool-proxy 容器内 curl coze callback（能解析）==="
echo "--- 不带任何鉴权 ---"
docker exec tool-proxy bash -c "curl -s -o /dev/null -w 'code=%{http_code}\n' -X POST http://coze-server:8888/api/v1/video/callback -H 'Content-Type: application/json' -d '{\"task_id\":\"p\",\"status\":\"completed\"}'"
echo "--- 带 X-Internal-Key（复用 scheduler key）试探 ---"
docker exec tool-proxy bash -c "curl -s -o /dev/null -w 'code=%{http_code}\n' -X POST http://coze-server:8888/api/v1/video/callback -H 'Content-Type: application/json' -H 'X-Internal-Key: sylab-sched-internal-2026' -d '{\"task_id\":\"p\",\"status\":\"completed\"}'"
echo "--- 一个明显不存在的路由，对比 404 vs 401 ---"
docker exec tool-proxy bash -c "curl -s -o /dev/null -w 'no-such-route code=%{http_code}\n' http://coze-server:8888/api/v1/zzz_nonexistent_xyz"
docker exec tool-proxy bash -c "curl -s -o /dev/null -w 'video-cb-GET code=%{http_code}\n' http://coze-server:8888/api/v1/video/callback"
echo
echo "=== 2) 二进制里 video / callback 字样是否存在（不限斜杠）==="
docker exec coze-server bash -c "grep -ic 'video' /tmp/oc.txt; grep -ic 'callback' /tmp/oc.txt"
docker exec coze-server bash -c "grep -in 'callback' /tmp/oc.txt | grep -ivE 'grpc|proto|gogo|http2|compile callbacks|callbacks\.' | head -10"
echo
echo "=== 3) tool 表里所有指向 tool-proxy(9092) 的自定义工具 ==="
docker exec coze-mysql mysql -uroot -pd3G8JG273iE8C4irRWJX opencoze -N -e "
SELECT id,name,COALESCE(base_url,'') FROM tool WHERE base_url LIKE '%9092%' OR base_url LIKE '%tool-proxy%' OR name LIKE '%video%' OR name LIKE '%视频%' LIMIT 40;" 2>/dev/null
echo "[DONE]"
