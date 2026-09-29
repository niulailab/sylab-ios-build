#!/bin/bash
MP=$(docker exec coze-mysql printenv MYSQL_ROOT_PASSWORD)
Q(){ docker exec coze-mysql mysql -uroot -p"$MP" opencoze -N -e "$1" 2>/dev/null; }

# 关注的 sub_url 集合
urls=(
 "/v1/web-search" "/search"
 "/video/generate" "/video/status/{task_id}" "/video/content/{task_id}"
 "/v1/file/generate" "/publish_web" "/file/extract"
 "/git_operation" "/bigmodel/v1/{path}" "/schedule/toggle"
 "/notifications/create" "/notifications/list"
 "/browser/content" "/screenshot"
 "/v1/image/generation"
)
printf "%-26s | %-22s | %s\n" "sub_url" "tool表(激活?) 数量" "本bot绑定(版本)"
printf '%.0s-' {1..80}; echo ""
for u in "${urls[@]}"; do
  # tool 表：用 sub_url 匹配（path型可能多条）
  tline=$(Q "SELECT CONCAT(COUNT(*),' 激活',SUM(activated_status=1)) FROM tool WHERE sub_url='$u' AND deleted_at IS NULL;" 2>/dev/null)
  [ -z "$tline" ] && tline="0"
  # agent_tool_version 本bot绑定
  aline=$(Q "SELECT GROUP_CONCAT(DISTINCT agent_version) FROM agent_tool_version WHERE agent_id=7669580347859795968 AND sub_url='$u';" 2>/dev/null)
  [ -z "$aline" ] && aline="—未绑定—"
  printf "%-26s | %-22s | %s\n" "$u" "$tline" "$aline"
done
echo "[DONE]"
