#!/bin/bash

echo "=== Step 1: 删除旧的 video_generate/video_status（无 v2）==="
docker exec coze-mysql mysql -uroot -pd3G8JG273iE8C4irRWJX opencoze -e "
DELETE FROM agent_tool_version
WHERE agent_id = 7669580347859795968
AND tool_name IN ('video_generate','video_status');" 2>/dev/null
echo "Deleted old tools."

echo
echo "=== Step 2: 验证只剩 v2 版本 ==="
docker exec coze-mysql mysql -uroot -pd3G8JG273iE8C4irRWJX opencoze -N -e "
SELECT id, tool_name, sub_url, method
FROM agent_tool_version
WHERE agent_id = 7669580347859795968
AND tool_name LIKE '%video%';" 2>/dev/null

echo
echo "=== Step 3: 查 user 表（看有没有用户记录）==="
docker exec coze-mysql mysql -uroot -pd3G8JG273iE8C4irRWJX opencoze -N -e "
SELECT user_id, COALESCE(username,''), COALESCE(email,'') FROM user LIMIT 5;" 2>/dev/null

echo
echo "=== Step 4: 查积分账户表 ==="
docker exec coze-mysql mysql -uroot -pd3G8JG273iE8C4irRWJX opencoze -N -e "SHOW TABLES LIKE '%balance%'; SHOW TABLES LIKE '%credit%'; SHOW TABLES LIKE '%point%'; SHOW TABLES LIKE '%account%';" 2>/dev/null

echo
echo "=== Step 5: 查积分相关表结构 ==="
docker exec coze-mysql mysql -uroot -pd3G8JG273iE8C4irRWJX opencoze -N -e "SHOW TABLES;" 2>/dev/null | grep -iE "balance|credit|point|account|user" | head -20

echo
echo "=== Step 6: 重启 coze-server（让工具定义刷新）==="
docker restart coze-server
echo "coze-server restarted"
sleep 15

echo
echo "=== Step 7: 查 Coze 框架日志（确认工具加载）==="
docker logs coze-server --since 30s 2>&1 | grep -iE "tool|plugin|video" | tail -20

echo "[DONE]"
