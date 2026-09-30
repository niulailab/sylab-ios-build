#!/usr/bin/env bash
set +e
RESULT=$(docker exec coze-mysql mysql -uroot -p"$(docker exec coze-mysql printenv MYSQL_ROOT_PASSWORD)" opencoze -e "SELECT id, title, schedule_type, next_run_time, last_run_time, run_count, status FROM scheduled_task WHERE status != 'deleted' ORDER BY id;" 2>&1)
RESULT+="\n\n=== recent runs ===\n"
RESULT+=$(docker exec coze-mysql mysql -uroot -p"$(docker exec coze-mysql printenv MYSQL_ROOT_PASSWORD)" opencoze -e "SELECT id, task_id, status, started_at, LEFT(error_message,200) as err FROM scheduled_task_run ORDER BY id DESC LIMIT 10;" 2>&1)
RESULT+="\n\n=== scheduler ===\n"
RESULT+=$(docker ps -a --filter name=scheduler --no-trunc 2>&1)
RESULT+="\n\n=== scheduler logs ===\n"
RESULT+=$(docker logs --tail 80 sylab-scheduler-service 2>&1 | tail -80)
echo -e "$RESULT" > /tmp/_r.txt
# 用 curl 调 GitHub API commit（PAT 从 env 取）
GT="${GITHUB_TOKEN:-}"
if [ -z "$GT" ]; then echo "NO GT"; exit 1; fi
B64=$(base64 -w0 /tmp/_r.txt)
SHA=$(curl -s -H "Authorization: token $GT" -H "Accept: application/vnd.github.v3+json" "https://api.github.com/repos/niulailab/sylab-ios-build/contents/output/sched_result.txt" | python3 -c "import json,sys;print(json.load(sys.stdin).get('sha',''))" 2>/dev/null)
if [ -n "$SHA" ]; then
  curl -s -X PUT -H "Authorization: token $GT" -H "Accept: application/vnd.github.v3+json" "https://api.github.com/repos/niulailab/sylab-ios-build/contents/output/sched_result.txt" -d "{\"message\":\"sched result\",\"content\":\"$B64\",\"branch\":\"main\",\"sha\":\"$SHA\"}"
else
  curl -s -X PUT -H "Authorization: token $GT" -H "Accept: application/vnd.github.v3+json" "https://api.github.com/repos/niulailab/sylab-ios-build/contents/output/sched_result.txt" -d "{\"message\":\"sched result\",\"content\":\"$B64\",\"branch\":\"main\"}"
fi
echo "COMMITTED"
