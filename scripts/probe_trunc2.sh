#!/bin/bash
echo "=== 1) 最近 10 条 sylab assistant 消息（看 finish_reason） ==="
docker exec coze-mysql mysql -uroot -pd3G8JG273iE8C4irRWJX opencoze --default-character-set=utf8mb4 -N -e "SELECT id, conversation_id, LEFT(content, 200), created_at FROM message WHERE role='assistant' AND content LIKE '%generate_answer_finish%' ORDER BY id DESC LIMIT 10;" 2>/dev/null
echo
echo "=== 2) 08:41 那段 09:00 任务产线的回复末尾 finish_reason ==="
docker exec coze-mysql mysql -uroot -pd3G8JG273iE8C4irRWJX opencoze --default-character-set=utf8mb4 -N -e "SELECT id, LEFT(content,200) FROM message WHERE id='7690751072322715648';" 2>/dev/null
echo
echo "=== 3) chat-queue SSE timeout 配置 ==="
grep -nE "SSE.*timeout|timeout.*sse|keepalive|heartbeat|SSE_TIMEOUT|HEARTBEAT" /root/chat-queue-service/server.js | head
echo
echo "=== 4) chat-queue 最近日志（看 SSE 是否断开） ==="
tail -150 /root/chat-queue-service/logs/chat-queue.log 2>/dev/null | grep -iE "sse|stream|timeout|disconnect|keepalive|heartbeat|err" | tail -20
echo
echo "=== 5) 最近是否有 max_tokens / length 截断（zhipu） ==="
docker logs tool-proxy --since "2026-09-29T00:00:00" 2>&1 | grep -iE "finish_reason.*length|max_token|truncat" | head -10
echo "(无输出=未因 max_tokens 截断)"
echo
echo "=== 6) 09:30 之后 zhipu 是否有异常（我的补丁时间段）==="
docker logs tool-proxy --since "2026-09-29T09:30:00" 2>&1 | grep -iE "error|exception|traceback|timeout" | head -10
echo "(无输出=补丁时间段无异常)"
echo "[DONE]"
