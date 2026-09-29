#!/bin/bash
MP=$(docker exec coze-mysql printenv MYSQL_ROOT_PASSWORD)
Q(){ docker exec coze-mysql mysql -uroot -p"$MP" opencoze -N -e "$1" 2>/dev/null; }

echo "===== tool / tool_version 关键列 ====="
docker exec coze-mysql mysql -uroot -p"$MP" opencoze -e "SELECT column_name FROM information_schema.columns WHERE table_schema='opencoze' AND table_name='tool' AND column_name IN ('id','name','tool_id','version','entity_id','unique_key');" 2>/dev/null | tr '\n' ' '; echo ""
docker exec coze-mysql mysql -uroot -p"$MP" opencoze -e "SELECT column_name FROM information_schema.columns WHERE table_schema='opencoze' AND table_name='tool_version' ORDER BY ordinal_position;" 2>/dev/null | tr '\n' ' '; echo ""

echo ""
echo "===== 关键工具在 tool 表里按名字查 ====="
Q "SELECT id, name FROM tool WHERE name IN ('web_search','video_generate_v2','video_status_v2','file_generate','get_content','generate_image_v2','publish_web') OR name LIKE '%video_generate%';"

echo ""
echo "===== agent_tool_version 的 tool_id 指向哪里：取样本 ====="
Q "SELECT DISTINCT tool_id FROM agent_tool_version WHERE agent_id=7669580347859795968 AND tool_name IN ('web_search','video_generate_v2','file_generate');"

echo ""
echo "===== tool_version 中是否有 video_generate / web_search ====="
Q "SELECT tool_id, version, LEFT(name,30) FROM tool_version WHERE name LIKE '%video_generate%' OR name LIKE '%web_search%' OR name='web_search' LIMIT 15;"
echo "[DONE]"
