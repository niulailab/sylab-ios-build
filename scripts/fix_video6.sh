#!/bin/bash
echo "=== 1) 查所有 tool 相关的表 ==="
docker exec coze-mysql mysql -uroot -pd3G8JG273iE8C4irRWJX opencoze -N -e "SHOW TABLES LIKE '%tool%';" 2>/dev/null

echo
echo "=== 2) 查 agent_tool_draft 表（看工具定义）==="
docker exec coze-mysql mysql -uroot -pd3G8JG273iE8C4irRWJX opencoze -N -e "
SELECT id, agent_id, tool_id, COALESCE(tool_name,''), COALESCE(sub_url,''), COALESCE(method,'')
FROM agent_tool_draft
WHERE tool_name LIKE '%video%' OR sub_url LIKE '%video%'
LIMIT 20;" 2>/dev/null

echo
echo "=== 3) 查 agent_tool_draft 表结构 ==="
docker exec coze-mysql mysql -uroot -pd3G8JG273iE8C4irRWJX opencoze -N -e "DESCRIBE agent_tool_draft;" 2>/dev/null

echo
echo "=== 4) 查所有 agent_tool_draft 记录 ==="
docker exec coze-mysql mysql -uroot -pd3G8JG273iE8C4irRWJX opencoze -N -e "
SELECT id, agent_id, tool_id, COALESCE(tool_name,''), COALESCE(method,''), COALESCE(sub_url,'')
FROM agent_tool_draft
ORDER BY id DESC LIMIT 30;" 2>/dev/null

echo
echo "=== 5) 查 bot 表 ==="
docker exec coze-mysql mysql -uroot -pd3G8JG273iE8C4irRWJX opencoze -N -e "SHOW TABLES LIKE '%bot%';" 2>/dev/null

echo
echo "=== 6) 查 agent 表 ==="
docker exec coze-mysql mysql -uroot -pd3G8JG273iE8C4irRWJX opencoze -N -e "
SELECT id, name, COALESCE(description,'') FROM agent WHERE name LIKE '%sylab%' LIMIT 10;" 2>/dev/null

echo "[DONE]"
