#!/bin/bash
docker exec coze-automation-service python -c "
import sqlite3,json
c=sqlite3.connect('/data/automation.db')
c.row_factory=sqlite3.Row
print('===== SCHEDULES =====')
for r in c.execute('select id,name,trigger_type,cron_expr,rrule,one_time_at,action_type,action_config,status,total_runs,success_count,fail_count,last_run_at,next_run_at from schedules'):
    d=dict(r)
    print(json.dumps(d,ensure_ascii=False,default=str))
print()
print('===== EXECUTION LOGS (latest) =====')
for r in c.execute('select id,schedule_id,status,triggered_at,duration_ms,error_message,response_body,coze_conversation_id from execution_logs order by id desc limit 10'):
    d=dict(r)
    if d.get('response_body'): d['response_body']=d['response_body'][:400]
    print(json.dumps(d,ensure_ascii=False,default=str))
"
echo ""
echo "=== grep actual auth header literal in source ==="
grep -nE "Authorization|Bearer|session|cookie|X-API" /root/coze-studio/automation-service/coze_client.py
