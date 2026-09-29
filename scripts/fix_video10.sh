#!/bin/bash
echo "=== 1) 查 Coze 框架最近 1 小时的 tool call 日志（看 video_generate 调用）==="
docker logs coze-server --since 1h 2>&1 | grep -B 5 -A 10 "video_generate\|tool.*call" | grep -vE "grpc|health" | tail -100

echo
echo "=== 2) 查 Coze 框架的 tool response 日志 ==="
docker logs coze-server --since 1h 2>&1 | grep -iE "tool.*response|tool.*result|tool.*output" | tail -50

echo
echo "=== 3) 查 Coze 框架的 HTTP 响应日志（看发给 AI 的是什么）==="
docker logs coze-server --since 1h 2>&1 | grep -iE "response.*tool|response.*data|response.*result" | tail -50

echo
echo "=== 4) 查 Coze 框架的完整日志（找 video 相关的所有内容）==="
docker logs coze-server --since 1h 2>&1 | grep -iE "video" | tail -50

echo "[DONE]"
