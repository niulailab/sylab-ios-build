#!/bin/bash
echo "=== 1) chat-queue recent logs (last 30) ==="
tail -30 /root/chat-queue-service/logs/*.log 2>/dev/null | tail -50
pm2 logs aitap --nostream --lines 30 2>/dev/null | tail -35
echo
echo "=== 2) tool-proxy 最近 30 行（看是否有 zhipu-proxy 异常/截断/timeout）==="
docker logs tool-proxy --tail 60 2>&1 | grep -iE "timeout|trunc|cancell|error|cut|finish_reason|stop|step|max_step|overload|429|503" | tail -25
echo
echo "=== 3) 看今天 08:30-09:05 那段 zhipu-proxy 是否出现 finish_reason != stop ==="
docker logs tool-proxy --since "2026-09-29T08:25:00" 2>&1 | grep -iE "zhipu-proxy|finish|stop_reason|length|max" | head -30
echo
echo "=== 4) 看 chat-queue SSE 是否有 stream error / incomplete ==="
docker logs chat-queue-service 2>&1 | tail -5 2>/dev/null || true
echo "(chat-queue 非 docker，看 pm2 logs)"
ls /root/chat-queue-service/logs/ 2>/dev/null
tail -100 /root/chat-queue-service/logs/combined.log 2>/dev/null | grep -iE "error|stream|timeout|retry|trunc|incomplete|cut" | tail -20
echo
echo "=== 5) 最近 message 表里最后一条 assistant，finish_reason 字段 ==="
docker exec coze-mysql mysql -uroot -pd3G8JG273iE8C4irRWJX opencoze --default-character-set=utf8mb4 -e "SELECT id,conversation_id,LEFT(content,80) c,created_at FROM message WHERE role='assistant' AND conversation_id='7687609248154386432' ORDER BY id DESC LIMIT 6;" 2>/dev/null
echo
echo "=== 6) 看 content 末尾的 generate_answer_finish data 是否有 max_tokens / length ==="
docker exec coze-mysql mysql -uroot -pd3G8JG273iE8C4irRWJX opencoze --default-character-set=utf8mb4 -N -e "SELECT content FROM message WHERE role='assistant' AND content LIKE '%generate_answer_finish%' AND conversation_id='7687609248154386432' ORDER BY id DESC LIMIT 1;" 2>/dev/null | python3 -c "
import sys,re,json
raw = sys.stdin.read()
m = re.search(r'\"data\":\"(.*?)\"(?:,|\})', raw)
if m:
    try: print(json.loads('\"'+m.group(1)+'\"'))
    except: print(m.group(1)[:300])
else:
    print('no finish marker found')
"
echo "[DONE]"
