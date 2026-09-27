#!/bin/bash
SC=coze-server
echo "=== reasoning strings ==="
docker exec "$SC" sh -lc "strings /app/opencoze | grep -iE 'reasoning_effort|reasoning_content|thinking_type|budget_tokens|enable_thinking' | sort -u | head -40"
echo "=== related go files ==="
docker exec "$SC" sh -lc "strings /app/opencoze | grep -iE 'reasoning|thinking' | grep '\.go' | sort -u | head -40"
echo DONE
