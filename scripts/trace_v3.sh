#!/bin/bash
SC=coze-server
echo "=== v3/openapi handler paths ==="
docker exec "$SC" sh -lc "strings /app/opencoze | grep -iE 'openapi|/v3/' | grep -iE '\.go|chat' | sort -u | head -60"
echo "=== GetByPublish / bot retrieve funcs ==="
docker exec "$SC" sh -lc "strings /app/opencoze | grep -iE 'singleagent' | grep -iE 'service|biz|handler' | grep '\.go' | sort -u | head -80"
echo DONE
