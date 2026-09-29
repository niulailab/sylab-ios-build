#!/bin/bash

echo "=== Step 1: 查 token_accounts 表结构 ==="
docker exec coze-mysql mysql -uroot -pd3G8JG273iE8C4irRWJX opencoze -N -e "DESCRIBE token_accounts;" 2>/dev/null

echo
echo "=== Step 2: 查 token_accounts 表数据 ==="
docker exec coze-mysql mysql -uroot -pd3G8JG273iE8C4irRWJX opencoze -N -e "
SELECT * FROM token_accounts LIMIT 5;" 2>/dev/null

echo
echo "=== Step 3: 查 space_user 表（看有没有空间用户）==="
docker exec coze-mysql mysql -uroot -pd3G8JG273iE8C4irRWJX opencoze -N -e "
SELECT * FROM space_user LIMIT 5;" 2>/dev/null

echo
echo "=== Step 4: 查 user 表结构 ==="
docker exec coze-mysql mysql -uroot -pd3G8JG273iE8C4irRWJX opencoze -N -e "DESCRIBE user;" 2>/dev/null

echo
echo "=== Step 5: 查 sylab bot 的配置（看 AI 怎么获取 user_id）==="
docker exec coze-mysql mysql -uroot -pd3G8JG273iE8C4irRWJX opencoze -N -e "
SELECT id, name, COALESCE(description,'') FROM agent WHERE id = 7669580347859795968;" 2>/dev/null

echo
echo "=== Step 6: 查最近的 tool call 日志（看 AI 调用 video_generate 时传了什么）==="
docker logs coze-server --since 10m 2>&1 | grep -iE "video_generate|tool_call" | grep -vE "grpc|health|register" | tail -30

echo "[DONE]"
