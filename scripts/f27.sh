#!/bin/bash
P=http://localhost:9092
echo "===== 1) 视频生成(提交,应返回task_id;不等待成片) ====="
curl -s -m 40 -X POST $P/video/generate -H 'Content-Type: application/json' \
 -d '{"prompt":"a cat walking on beach, cinematic","duration":5}' | head -c 500
echo ""; echo ""
echo "===== 2) publish_web ====="
curl -s -m 30 -X POST $P/publish_web -H 'Content-Type: application/json' \
 -d '{"html":"<html><body><h1>rootfix test</h1></body></html>","title":"rootfix"}' | head -c 400
echo ""; echo ""
echo "===== 3) notifications create + list ====="
curl -s -m 25 -X POST $P/notifications/create -H 'Content-Type: application/json' \
 -d '{"title":"rootfix测试","content":"通知链路验证","notif_type":"task"}' | head -c 250
echo ""
curl -s -m 25 "$P/notifications/list?size=3" | head -c 250
echo ""; echo ""
echo "===== 4) schedule toggle(不存在id应返回明确错误而非空) ====="
curl -s -m 20 -X POST $P/schedule/toggle -H 'Content-Type: application/json' \
 -d '{"schedule_id":"nonexistent_test_id","enabled":false}' | head -c 250
echo ""; echo ""
echo "===== 5) git_operation(状态类,应正常响应) ====="
curl -s -m 25 -X POST $P/git_operation -H 'Content-Type: application/json' \
 -d '{"operation":"--version"}' | head -c 250
echo ""
echo "[DONE]"
