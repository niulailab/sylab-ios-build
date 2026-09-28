#!/bin/bash
# Find previous chat test scripts that worked
echo "=== /tmp test scripts ==="
ls -la /tmp/*.sh /tmp/*.py 2>/dev/null | grep -iE 'chat|test|replay|real' | head -20

echo ""
echo "=== /root test scripts ==="
find /root -maxdepth 2 -name "*chat*" -o -name "*test*" -o -name "*replay*" 2>/dev/null | grep -v node_modules | grep -v '.git' | head -20

echo ""
echo "=== Check scripts in coze-studio ==="
find /root/coze-studio -maxdepth 3 -name "*chat*test*" -o -name "*real*chat*" 2>/dev/null | head -10

echo ""
echo "=== grep for session_key or cookie in /tmp scripts ==="
grep -l "session_key\|Cookie\|cookie" /tmp/*.sh /tmp/*.py 2>/dev/null | head -10

echo ""
echo "=== grep for Bearer or PAT in /tmp scripts ==="
grep -l "Bearer\|pat_\|Personal" /tmp/*.sh /tmp/*.py 2>/dev/null | head -10
