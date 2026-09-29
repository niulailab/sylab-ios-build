#!/bin/bash
echo "=== 1) 查 video_generate_v2 的 operation JSON ==="
docker exec coze-mysql mysql -uroot -pd3G8JG273iE8C4irRWJX opencoze -N -e "
SELECT operation FROM agent_tool_draft WHERE tool_name = 'video_generate_v2' AND agent_id = 7669580347859795968;" 2>/dev/null | python3 -m json.tool 2>/dev/null || echo "JSON parse failed"

echo
echo "=== 2) 查 video_status_v2 的 operation JSON ==="
docker exec coze-mysql mysql -uroot -pd3G8JG273iE8C4irRWJX opencoze -N -e "
SELECT operation FROM agent_tool_draft WHERE tool_name = 'video_status_v2' AND agent_id = 7669580347859795968;" 2>/dev/null | python3 -m json.tool 2>/dev/null || echo "JSON parse failed"

echo
echo "=== 3) 查 agent_tool_version 表（看已发布的工具版本）==="
docker exec coze-mysql mysql -uroot -pd3G8JG273iE8C4irRWJX opencoze -N -e "
SELECT id, agent_id, tool_id, COALESCE(tool_name,''), COALESCE(sub_url,''), COALESCE(method,'')
FROM agent_tool_version
WHERE tool_name LIKE '%video%' OR agent_id = 7669580347859795968
ORDER BY id DESC LIMIT 20;" 2>/dev/null

echo
echo "=== 4) 查 tool 表（全局工具定义）==="
docker exec coze-mysql mysql -uroot -pd3G8JG273iE8C4irRWJX opencoze -N -e "
SELECT id, COALESCE(name,''), COALESCE(description,'') FROM tool WHERE name LIKE '%video%' LIMIT 10;" 2>/dev/null

echo
echo "=== 5) 查 tool_version 表（工具版本定义）==="
docker exec coze-mysql mysql -uroot -pd3G8JG273iE8C4irRWJX opencoze -N -e "
SELECT id, tool_id, COALESCE(version,''), COALESCE(status,'') FROM tool_version WHERE tool_id IN (
  SELECT id FROM tool WHERE name LIKE '%video%'
) ORDER BY id DESC LIMIT 10;" 2>/dev/null

echo "[DONE]"
