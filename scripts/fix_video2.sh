#!/bin/bash
echo "=== 1) plugin 表里所有视频相关 ==="
docker exec coze-mysql mysql -uroot -pd3G8JG273iE8C4irRWJX opencoze -N -e "
SELECT id,name,status FROM plugin WHERE name LIKE '%video%' OR name LIKE '%视频%' OR name LIKE '%生成%' OR name LIKE '%海%' OR name LIKE '%running%' LIMIT 30;" 2>/dev/null
echo
echo "=== 2) plugin_version 表看视频插件有没有版本 ==="
docker exec coze-mysql mysql -uroot -pd3G8JG273iE8C4irRWJX opencoze -N -e "
SELECT pv.id,pv.plugin_id,p.name,pv.version,pv.status
FROM plugin_version pv JOIN plugin p ON p.id=pv.plugin_id
WHERE p.name LIKE '%video%' OR p.name LIKE '%视频%' OR p.name LIKE '%海%' OR p.name LIKE '%running%' OR p.name LIKE '%H3%'
ORDER BY pv.id DESC LIMIT 20;" 2>/dev/null
echo
echo "=== 3) 所有 tool 表工具（看有没有 video 相关的）==="
docker exec coze-mysql mysql -uroot -pd3G8JG273iE8C4irRWJX opencoze -N -e "SELECT id,name,status,base_url FROM tool WHERE name LIKE '%video%' OR name LIKE '%视频%' OR name LIKE '%H3%' OR name LIKE '%生成%';" 2>/dev/null
echo
echo "=== 4) 所有 tool 表（总览，看有没有 video 字样）==="
docker exec coze-mysql mysql -uroot -pd3G8JG273iE8C4irRWJX opencoze -N -e "SELECT name FROM tool;" 2>/dev/null | sort
echo
echo "=== 5) sylab bot 绑定了哪些 tool ==="
docker exec coze-mysql mysql -uroot -pd3G8JG273iE8C4irRWJX opencoze -N -e "SHOW TABLES LIKE '%bot_tool%'; SHOW TABLES LIKE '%agent_tool%'; SHOW TABLES LIKE '%app_tool%';" 2>/dev/null
echo "[DONE]"
