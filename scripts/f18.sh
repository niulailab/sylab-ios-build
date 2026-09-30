#!/bin/bash
echo "===== bot_creator.py 行数/结构 ====="
wc -l /root/coze-studio/tool-proxy/bot_creator.py
grep -nE "^def |^class |INSERT|agent_tool|tool_version|def register|plugin|snowflake|def main|__main__" /root/coze-studio/tool-proxy/bot_creator.py | head -50
echo "[DONE]"
