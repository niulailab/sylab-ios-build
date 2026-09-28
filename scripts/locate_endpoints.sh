#!/bin/bash
grep -nE "/schedule/create|/schedule/list|/internal/fire|scheduler_loop|_scheduler_tick" /root/coze-studio/tool-proxy/server.py | head -20
echo "--- health check live ---"
curl -s -m 10 http://127.0.0.1:9092/schedule/health
