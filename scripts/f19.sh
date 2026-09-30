#!/bin/bash
MP=$(docker exec coze-mysql printenv MYSQL_ROOT_PASSWORD)
Q(){ docker exec coze-mysql mysql -uroot -p"$MP" opencoze -N -e "$1" 2>/dev/null; }
C(){ docker exec coze-mysql mysql -uroot -p"$MP" opencoze -e "$1" 2>/dev/null; }

echo "===== plugin 表列 ====="
Q "SELECT column_name FROM information_schema.columns WHERE table_schema='opencoze' AND table_name='plugin';" | tr '\n' ' '; echo ""
echo "===== plugin_version 列 ====="
Q "SELECT column_name FROM information_schema.columns WHERE table_schema='opencoze' AND table_name='plugin_version';" | tr '\n' ' '; echo ""
echo ""
echo "===== 视频工具所属 plugin 7667500000000001001 完整信息 ====="
C "SELECT * FROM plugin WHERE id=7667500000000001001\G"
echo "===== 对应 plugin_version ====="
C "SELECT * FROM plugin_version WHERE plugin_id=7667500000000001001\G" | head -30
echo "[DONE]"
