#!/bin/bash
echo "=== 1) tool-proxy 里所有 video 相关路由 ==="
grep -nE "@app\.(get|post|api_route).*video|/video" /root/coze-studio/tool-proxy/server.py | head -20
echo
echo "=== 2) server.py 里 video 关键词（看走哪个上游）==="
grep -niE "video|runninghub|hailuo|海螺|h3|kling|可灵|wanvideo|wan2|klingai|minimax" /root/coze-studio/tool-proxy/server.py | head -30
echo
echo "=== 3) Coze 里的视频插件（数据库 tool/plugin 表）==="
docker exec coze-mysql mysql -uroot -pd3G8JG273iE8C4irRWJX opencoze -N -e "
SELECT id, name, COALESCE(base_url,'') FROM tool WHERE name LIKE '%video%' OR name LIKE '%视频%' OR base_url LIKE '%runninghub%' OR base_url LIKE '%hailuo%' LIMIT 20;" 2>/dev/null
echo
echo "=== 4) plugin 表找视频/海螺/runninghub ==="
docker exec coze-mysql mysql -uroot -pd3G8JG273iE8C4irRWJX opencoze -N -e "
SELECT id, name FROM plugin WHERE name LIKE '%video%' OR name LIKE '%视频%' OR name LIKE '%海螺%' OR name LIKE '%running%' LIMIT 20;" 2>/dev/null
echo
echo "=== 5) 宿主机直连 RunningHub 健康 ==="
curl -s -o /dev/null -w "runninghub.cn http=%{http_code} ttfb=%{time_starttransfer}s\n" --max-time 15 "https://www.runninghub.cn/" 2>&1
echo
echo "=== 6) bot 绑定的工具里有没有视频工具（sylab主bot）==="
docker exec coze-mysql mysql -uroot -pd3G8JG273iE8C4irRWJX opencoze -N -e "
SELECT bot_id, tool_id FROM bot_tool WHERE bot_id IN (SELECT DISTINCT bot_id FROM sylab_scheduled_tasks) LIMIT 20;" 2>/dev/null || echo "无 bot_tool 表或查不到"
echo "[DONE]"
