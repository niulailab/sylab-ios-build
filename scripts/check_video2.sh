#!/bin/bash
echo "=== 1) video_generate_v2 走哪个上游 + 模型清单 ==="
grep -nE "MODEL_PRICING|veo|seedance|kling|wan|sora|model.*:.*\{|cost|seconds" /root/coze-studio/tool-proxy/server.py | sed -n '1,40p' | grep -iE "veo|seedance|kling|wan|sora|MODEL_PRICING" | head -25
echo
echo "=== 2) v2 视频函数本体（找 video_generate_v2）==="
grep -n "def video_generate_v2\|def video_status_v2\|def video_content_v2" /root/coze-studio/tool-proxy/server.py
echo
echo "=== 3) 上游 YanBa clmm-mall.top 健康度 ==="
curl -s -o /dev/null -w "clmm-mall.top http=%{http_code} ttfb=%{time_starttransfer}s\n" --max-time 15 "https://clmm-mall.top/" 2>&1
curl -s --max-time 15 "https://clmm-mall.top/v1/videos" -w "\n[http=%{http_code}]\n" 2>&1 | tail -5
echo
echo "=== 4) 本机直调 tool-proxy /video/generate（quote 报价动作，不真扣费）==="
curl -s --max-time 20 -X POST "http://127.0.0.1:9092/video/generate" \
  -H "Content-Type: application/json" \
  -d '{"action":"quote","prompt":"a cat running","model":"veo-3.1-fast-720p-8s","user_id":"probe_test"}' \
  -w "\n[http=%{http_code}]\n" 2>&1 | head -20
echo
echo "=== 5) Coze bot 实际配置的视频工具：查 bot 表的 tools JSON ==="
docker exec coze-mysql mysql -uroot -pd3G8JG273iE8C4irRWJX opencoze -N -e "SHOW TABLES LIKE '%tool%';" 2>/dev/null
docker exec coze-mysql mysql -uroot -pd3G8JG273iE8C4irRWJX opencoze -N -e "SHOW TABLES LIKE '%plugin%';" 2>/dev/null
echo "[DONE]"
