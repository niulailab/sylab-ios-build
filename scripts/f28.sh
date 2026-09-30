#!/bin/bash
P=http://localhost:9092
MP=$(docker exec coze-mysql printenv MYSQL_ROOT_PASSWORD)
echo "===== 找一个真实用户ID(取消息表发送方) ====="
UIDV=$(docker exec coze-mysql mysql -uroot -p"$MP" opencoze -N -e "SELECT DISTINCT sender_id FROM message WHERE sender_type=1 LIMIT 1;" 2>/dev/null)
[ -z "$UIDV" ] && UIDV=2697531370768443
echo "use user_id=$UIDV"
echo ""
echo "===== 1) notification create(带user_id) ====="
curl -s -m 25 -X POST $P/notifications/create -H 'Content-Type: application/json' \
 -d "{\"user_id\":\"$UIDV\",\"title\":\"rootfix测试\",\"content\":\"通知链路验证\",\"notif_type\":\"task\"}" | head -c 300
echo ""
echo "===== 2) notification list(带user_id) ====="
curl -s -m 25 -X POST $P/notifications/list -H 'Content-Type: application/json' \
 -d "{\"user_id\":\"$UIDV\",\"size\":3}" | head -c 350
echo ""; echo ""
echo "===== 3) bigmodel 代理 GET(列模型,验证透传) ====="
curl -s -m 30 "$P/bigmodel/v1/models" | head -c 300
echo ""; echo ""
echo "===== 4) video content 不存在id(明确错误) ====="
curl -s -m 20 "$P/video/content/nonexistent_test_task" | head -c 250
echo ""
echo "[DONE]"
