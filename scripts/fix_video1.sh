#!/bin/bash
echo "=== 1) tool 表里 video_generate 完整 schema ==="
docker exec coze-mysql mysql -uroot -pd3G8JG273iE8C4irRWJX opencoze -N -e "
SELECT id,name,status,COALESCE(base_url,''),
       COALESCE(JSON_UNQUOTE(JSON_EXTRACT(parameters,'$.response_schema')),JSON_EXTRACT(parameters,'$.output_format'),'') as resp_schema,
       LENGTH(COALESCE(JSON_UNQUOTE(JSON_EXTRACT(parameters,'$.response_schema')),JSON_EXTRACT(parameters,'$.output_format'),'')) as resp_len
FROM tool WHERE name LIKE '%video%' OR name LIKE '%视频%';" 2>/dev/null
echo
echo "=== 2) 同时看所有 9092 自定义工具（找视频相关）==="
docker exec coze-mysql mysql -uroot -pd3G8JG273iE8C4irRWJX opencoze -N -e "
SELECT id,name,status,base_url,
       COALESCE(JSON_UNQUOTE(JSON_EXTRACT(parameters,'$.response_schema')),JSON_EXTRACT(parameters,'$.output_format'),'') as resp
FROM tool WHERE base_url LIKE '%9092%' OR base_url LIKE '%tool-proxy%';" 2>/dev/null
echo
echo "=== 3) tool_draft 里有没有 video 草稿版本 ==="
docker exec coze-mysql mysql -uroot -pd3G8JG273iE8C4irRWJX opencoze -N -e "
SELECT id,tool_id,name,status FROM tool_draft WHERE name LIKE '%video%' OR name LIKE '%视频%';" 2>/dev/null
echo "[DONE]"
