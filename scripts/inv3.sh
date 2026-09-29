#!/bin/bash
MP=$(docker exec coze-mysql printenv MYSQL_ROOT_PASSWORD)
Q(){ docker exec coze-mysql mysql -uroot -p"$MP" opencoze -e "$1" 2>/dev/null; }
echo "### model_instance 全部核心字段 ###"
Q "SELECT id, type, provider, LEFT(display_info,60) disp, LEFT(capability,120) cap FROM model_instance WHERE deleted_at IS NULL OR deleted_at=0;"
echo ""
echo "### 完整记录(connection/capability/parameters) ###"
Q "SELECT id,type,provider,connection,capability,parameters,extra FROM model_instance\G" 2>&1 | head -120
echo "[DONE]"
