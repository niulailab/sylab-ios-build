#!/usr/bin/env bash
set +e
OUT=$(docker exec coze-mysql mysql -uroot -p"$(docker exec coze-mysql printenv MYSQL_ROOT_PASSWORD)" opencoze -e "SELECT id, title, schedule_type, next_run_time, last_run_time, run_count, status FROM scheduled_task WHERE status != 'deleted' ORDER BY id;" 2>&1)
OUT+=$'\n\n=== recent runs ===\n'
OUT+=$(docker exec coze-mysql mysql -uroot -p"$(docker exec coze-mysql printenv MYSQL_ROOT_PASSWORD)" opencoze -e "SELECT id, task_id, status, started_at, LEFT(error_message,200) as err FROM scheduled_task_run ORDER BY id DESC LIMIT 10;" 2>&1)
OUT+=$'\n\n=== scheduler ===\n'
OUT+=$(docker ps -a --filter name=scheduler --no-trunc 2>&1)
OUT+=$'\n\n=== scheduler logs ===\n'
OUT+=$(docker logs --tail 100 sylab-scheduler-service 2>&1 | tail -100)
echo "$OUT" > /tmp/_r.txt
B64=$(base64 -w0 /tmp/_r.txt)
GT="$GITHUB_TOKEN"
echo "GT len=${#GT}"
# 读现有 sha
SHA=$(curl -s -H "Authorization: token $GT" "https://api.github.com/repos/niulailab/sylab-ios-build/contents/output/sched.txt" 2>/dev/null | python3 -c "import json,sys;d=json.load(sys.stdin);print(d.get('sha',''))" 2>/dev/null || echo "")
echo "SHA=$SHA"
if [ -n "$SHA" ]; then
  curl -s -X PUT -H "Authorization: token $GT" -H "Accept: application/vnd.github.v3+json" \
    "https://api.github.com/repos/niulailab/sylab-ios-build/contents/output/sched.txt" \
    -d "{\"message\":\"sched $(date +%s)\",\"content\":\"$B64\",\"branch\":\"main\",\"sha\":\"$SHA\"}"
else
  curl -s -X PUT -H "Authorization: token $GT" -H "Accept: application/vnd.github.v3+json" \
    "https://api.github.com/repos/niulailab/sylab-ios-build/contents/output/sched.txt" \
    -d "{\"message\":\"sched $(date +%s)\",\"content\":\"$B64\",\"branch\":\"main\"}"
fi
echo "COMMITTED"
