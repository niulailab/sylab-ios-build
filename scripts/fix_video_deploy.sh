#!/bin/bash
set -e

echo "=== Step 1: 备份 agent_tool_version 表 ==="
docker exec coze-mysql mysqldump -uroot -pd3G8JG273iE8C4irRWJX opencoze agent_tool_version > /tmp/agent_tool_version_backup.sql 2>/dev/null
echo "Backup saved to /tmp/agent_tool_version_backup.sql"

echo
echo "=== Step 2: 检查是否已有 video 工具在 version 表 ==="
EXISTING=$(docker exec coze-mysql mysql -uroot -pd3G8JG273iE8C4irRWJX opencoze -N -e "
SELECT COUNT(*) FROM agent_tool_version
WHERE agent_id = 7669580347859795968
AND tool_name IN ('video_generate_v2','video_status_v2');" 2>/dev/null)
echo "Existing video tools in version table: $EXISTING"

if [ "$EXISTING" -gt 0 ]; then
  echo "Already exists, skip insert"
else
  echo "Inserting video_generate_v2 and video_status_v2 into version table..."
  docker exec coze-mysql mysql -uroot -pd3G8JG273iE8C4irRWJX opencoze -e "
    INSERT INTO agent_tool_version (id, agent_id, plugin_id, tool_id, agent_version, tool_name, tool_version, sub_url, method, operation, created_at, source)
    SELECT id, agent_id, plugin_id, tool_id, '1', tool_name, '1', sub_url, method, operation, UNIX_TIMESTAMP(), 0
    FROM agent_tool_draft
    WHERE agent_id = 7669580347859795968
    AND tool_name IN ('video_generate_v2','video_status_v2');
  " 2>/dev/null
  echo "Inserted."
fi

echo
echo "=== Step 3: 验证插入 ==="
docker exec coze-mysql mysql -uroot -pd3G8JG273iE8C4irRWJX opencoze -N -e "
SELECT id, agent_id, tool_name, sub_url, method
FROM agent_tool_version
WHERE agent_id = 7669580347859795968
AND tool_name LIKE '%video%';" 2>/dev/null

echo
echo "=== Step 4: 检查 response schema ==="
docker exec coze-mysql mysql -uroot -pd3G8JG273iE8C4irRWJX opencoze -N -e "
SELECT tool_name, JSON_EXTRACT(operation, '$.responses.200.content.application/json.schema.properties') as response_props
FROM agent_tool_version
WHERE agent_id = 7669580347859795968
AND tool_name IN ('video_generate_v2','video_status_v2');" 2>/dev/null

echo
echo "=== Step 5: 重启 coze-server 让工具定义生效 ==="
docker restart coze-server
echo "coze-server restarted"

echo
echo "=== Step 6: 等待 coze-server 启动完成 ==="
sleep 15
docker exec coze-server curl -s --max-time 10 http://localhost:8888/health || echo "Health check pending..."

echo
echo "[DONE]"
