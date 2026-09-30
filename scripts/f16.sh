#!/bin/bash
MP=$(docker exec coze-mysql printenv MYSQL_ROOT_PASSWORD)
Q(){ docker exec coze-mysql mysql -uroot -p"$MP" opencoze -N -e "$1" 2>/dev/null; }
CUR=7669597666208120832
BOT=7669580347859795968

echo "当前版本已绑定数: $(Q "SELECT COUNT(*) FROM agent_tool_version WHERE agent_id=$BOT AND agent_version=$CUR;")"
echo "其它版本绑定数(将被忽略): $(Q "SELECT COUNT(*) FROM agent_tool_version WHERE agent_id=$BOT AND agent_version<>$CUR;")"
echo ""
echo "===== 当前版本已绑定 sub_url 列表 ====="
Q "SELECT sub_url FROM agent_tool_version WHERE agent_id=$BOT AND agent_version=$CUR ORDER BY sub_url;" | tr '\n' ' '
echo ""; echo ""
echo "===== tool 表里存在、但当前版本没绑定的(候选直绑) ====="
Q "SELECT t.id,t.sub_url,t.method,t.activated_status FROM tool t WHERE t.activated_status=1 AND NOT EXISTS(SELECT 1 FROM agent_tool_version a WHERE a.agent_id=$BOT AND a.agent_version=$CUR AND a.tool_id=t.id) ORDER BY t.sub_url;"
echo "[DONE]"
