#!/bin/bash
echo "===== 运行时加载工具是否按 agent_version 严格过滤 ====="
timeout 55 grep -rniE "agent_version|AgentVersion" /root/coze-studio/backend/domain/plugin /root/coze-studio/backend/domain/agent --include=*.go 2>/dev/null | grep -viE "_test|\.bak" | grep -iE "tool|version|where|=" | head -20
echo ""
echo "===== agent_tool_version.go 查询入口 ====="
grep -nE "func |agent_version|AgentVersion|WHERE|Where" /root/coze-studio/backend/domain/plugin/internal/dal/agent_tool_version.go 2>/dev/null | head -25
echo "[DONE]"
