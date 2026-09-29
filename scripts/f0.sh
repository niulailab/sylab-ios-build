#!/bin/bash
MP=$(docker exec coze-mysql printenv MYSQL_ROOT_PASSWORD)
Q(){ docker exec coze-mysql mysql -uroot -p"$MP" opencoze -N -e "$1" 2>/dev/null; }

echo "===== 1) 博查 key 线索(只显示是否存在+前后掩码) ====="
for f in /root/.bashrc /root/coze-studio/.env /root/coze-studio/docker/.env /root/coze-studio/tool-proxy/.env; do
 [ -f "$f" ] && k=$(grep -i "BOCHA" "$f" 2>/dev/null | head -1) && [ -n "$k" ] && echo "$f -> ${k:0:22}...(len=${#k})"
done
echo "-- 全盘找 BOCHA key 字面量(掩码) --"
grep -rIl "BOCHA_API_KEY" /root/coze-studio 2>/dev/null | grep -vE "\.go$|\.md$|node_modules" | head
grep -rIh "BOCHA_API_KEY *= *['\"]skf-" /root/coze-studio 2>/dev/null | head -3 | sed -E "s/(skf-.{4}).*/\1****/" 

echo ""
echo "===== 2) 当前 bot 当前版本 ====="
Q "SELECT id,version FROM agent WHERE id=7669580347859795968;" 2>/dev/null
echo "-- agent 表列 --"
docker exec coze-mysql mysql -uroot -p"$MP" opencoze -N -e "SELECT column_name FROM information_schema.columns WHERE table_schema='opencoze' AND table_name='agent';" 2>/dev/null | tr '\n' ' '; echo ""

echo ""
echo "===== 3) 自定义工具 plugin 归属分布 ====="
Q "SELECT plugin_id, COUNT(*) c FROM tool GROUP BY plugin_id ORDER BY c DESC;"

echo ""
echo "===== 4) tool-proxy compose/启动方式 ====="
grep -rIn "tool-proxy" /root/coze-studio/docker 2>/dev/null | grep -iE "compose|yaml|\.yml" | head
ls /root/coze-studio/docker/*.yaml /root/coze-studio/docker/*.yml 2>/dev/null
find /root/coze-studio -maxdepth 2 -name "docker-compose*.y*ml" 2>/dev/null
echo "[DONE]"
