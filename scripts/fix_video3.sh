#!/bin/bash
echo "=== 1) agent_tool_version 表结构 ==="
docker exec coze-mysql mysql -uroot -pd3G8JG273iE8C4irRWJX opencoze -N -e "DESCRIBE agent_tool_version;" 2>/dev/null
echo
echo "=== 2) 所有 agent_tool_version 记录（找 video 相关）==="
docker exec coze-mysql mysql -uroot -pd3G8JG273iE8C4irRWJX opencoze -N -e "
SELECT id, agent_id, tool_id, COALESCE(name,''), COALESCE(tool_type,''), COALESCE(base_url,''), COALESCE(method,''), COALESCE(path,'')
FROM agent_tool_version
WHERE name LIKE '%video%' OR name LIKE '%视频%' OR name LIKE '%H3%' OR path LIKE '%video%'
ORDER BY id DESC LIMIT 30;" 2>/dev/null
echo
echo "=== 3) 所有 agent_tool_version 记录（总览）==="
docker exec coze-mysql mysql -uroot -pd3G8JG273iE8C4irRWJX opencoze -N -e "
SELECT id, agent_id, tool_id, COALESCE(name,''), COALESCE(path,''), COALESCE(base_url,'')
FROM agent_tool_version ORDER BY id DESC LIMIT 50;" 2>/dev/null
echo
echo "=== 4) 看 tool-proxy 视频端点完整返回（确认是不是真的空）==="
# 直调 quote（已知正常）和 generate（带有效参数）
echo "--- quote（已知好）---"
curl -s --max-time 15 -X POST "http://127.0.0.1:9092/video/generate" \
  -H "Content-Type: application/json" \
  -H "X-AiPlugin-Connector-Identifier: probe" \
  -d '{"action":"quote","prompt":"a cat running","model":"veo-3.1-fast-720p-8s","user_id":"probe_test"}' | head -c 400
echo
echo "--- generate（不带 quote，看错误处理）---"
curl -s --max-time 15 -X POST "http://127.0.0.1:9092/video/generate" \
  -H "Content-Type: application/json" \
  -H "X-AiPlugin-Connector-Identifier: probe" \
  -d '{"action":"generate","prompt":"a cat running","model":"veo-3.1-fast-720p-8s","user_id":"probe_test"}' | head -c 400
echo
echo "[DONE]"
