#!/bin/bash
echo "### 1. coze-video-service 容器（端口8960）###"
docker ps --format '{{.Names}} | {{.Ports}}' | grep 8960

echo ""
echo "### 2. 目标run 中LLM请求的thinking开关（只grep关键行,限量）###"
timeout 60 docker logs coze-server --since 6h 2>&1 | grep "7ebcc4cb" | grep -oE "(enable_thinking|thinking|reasoning_effort)[\":= ]+[a-z0-9]+" | sort | uniq -c | head

echo ""
echo "### 3. 目标run实际调用的视频服务路径统计 ###"
timeout 60 docker logs coze-server --since 6h 2>&1 | grep "7ebcc4cb" | grep -oE "coze-video-service:8960[^ \"\\]*" | sort | uniq -c | head

echo ""
echo "### 4. 模型调用走的哪个服务（非run_command的内网端点）###"
timeout 60 docker logs coze-server --since 6h 2>&1 | grep "7ebcc4cb" | grep -oE "172.18.0.1:9097/execute|0.0.0.0:8960[^ ]*" | sort | uniq -c | head

echo "[DONE]"
