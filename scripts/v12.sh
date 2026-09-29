#!/bin/bash
MP=$(docker exec coze-mysql printenv MYSQL_ROOT_PASSWORD)
Q(){ docker exec coze-mysql mysql -uroot -p"$MP" opencoze -N -e "$1" 2>/dev/null; }
echo "### tool 表 sub_url 总数(不过滤deleted_at) ###"
Q "SELECT COUNT(DISTINCT sub_url) FROM tool;"
echo ""
urls=(
 "/v1/web-search" "/search"
 "/video/generate" "/video/status/{task_id}" "/video/content/{task_id}"
 "/v1/file/generate" "/publish_web" "/file/extract"
 "/git_operation" "/bigmodel/v1/{path}" "/schedule/toggle"
 "/notifications/create" "/notifications/list"
 "/browser/content" "/screenshot" "/v1/image/generation"
)
printf "%-26s | %-18s | %s\n" "sub_url" "tool(总数/激活)" "本bot绑定版本"
printf '%.0s-' {1..78}; echo ""
for u in "${urls[@]}"; do
  tc=$(Q "SELECT CONCAT(COUNT(*),'/',COALESCE(SUM(activated_status=1),0)) FROM tool WHERE sub_url='$u';")
  [ -z "$tc" ] && tc="0/0"
  av=$(Q "SELECT GROUP_CONCAT(DISTINCT IFNULL(agent_version,'NULLver')) FROM agent_tool_version WHERE agent_id=7669580347859795968 AND sub_url='$u';")
  [ -z "$av" ] && av="—未绑定—"
  printf "%-26s | %-18s | %s\n" "$u" "$tc" "$av"
done
echo "[DONE]"
