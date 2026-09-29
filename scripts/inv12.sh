#!/bin/bash
echo "### HTTP 路由注册入口（含chat/message/debug/internal）###"
timeout 50 grep -rniE "\.POST\(|\.GET\(|Handle\(|AddRoute|router\." /root/coze-studio/backend --include=*.go 2>/dev/null | grep -viE "_test|\.bak|api/model|mock" | grep -iE "chat|message|conversation|debug|internal|run" | head -20
echo ""
echo "### 鉴权中间件白名单/内网放行 ###"
timeout 40 grep -rniE "x-forwarded|whitelist|白名单|127.0.0.1|172\.|skipAuth|noAuth|trusted" /root/coze-studio/backend --include=*.go 2>/dev/null | grep -viE "_test|\.bak|api/model|mock" | head -12
echo ""
echo "### 是否有内部debug/测试触发脚本 ###"
ls /root/*.sh 2>/dev/null | grep -iE "test|debug|chat|trigger|send" | head
echo "[DONE]"
