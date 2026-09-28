#!/bin/bash
F=/root/coze-studio/tool-proxy/server.py
# find function start/end
START=$(grep -n 'async def zhipu_proxy' "$F" | head -1 | cut -d: -f1)
echo "func starts at $START"
# print from a bit before the route def to next top-level def after START
sed -n "$((START-12)),$((START+220))p" "$F"
echo DONE
