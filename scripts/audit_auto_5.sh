#!/bin/bash
echo "=== coze_client.py chat_with_bot rest + run_workflow ==="
sed -n '120,280p' /root/coze-studio/automation-service/coze_client.py

echo ""
echo "=== ALL automation container env ==="
docker inspect coze-automation-service --format '{{range .Config.Env}}{{println .}}{{end}}'

echo ""
echo "=== automation.db tables + counts ==="
docker exec coze-automation-service sh -c "ls -la /data/ && python -c \"
import sqlite3
c=sqlite3.connect('/data/automation.db')
print([r[0] for r in c.execute(\\\"select name from sqlite_master where type='table'\\\")])
for t in ['schedules','execution_logs','bot_cache','workflow_cache']:
    try:
        n=c.execute(f'select count(*) from {t}').fetchone()[0]
        print(t,n)
    except Exception as e: print(t,'ERR',e)
\""
