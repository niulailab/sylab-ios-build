#!/bin/bash
echo "### openai.go builder 思考处理 ###"
grep -nE "ThinkingType|reasoning|thinking|ReasoningEffort" /root/coze-studio/backend/bizpkg/llm/modelbuilder/openai.go 2>/dev/null | head -20
echo ""
echo "### modelbuilder 目录文件 ###"
ls -la /root/coze-studio/backend/bizpkg/llm/modelbuilder/ 2>/dev/null
echo ""
echo "### glm/bigmodel 专用builder? ###"
grep -rlnE "bigmodel|glm" /root/coze-studio/backend/bizpkg/llm/ 2>/dev/null | grep -viE "_test|\.bak" | head
echo ""
echo "### 当前bot版本 model_info 与发布状态 ###"
MP=$(docker exec coze-mysql printenv MYSQL_ROOT_PASSWORD)
docker exec coze-mysql mysql -uroot -p"$MP" opencoze -e "SELECT id,agent_id,status,publish_status FROM single_agent_version WHERE agent_id=7669580347859795968 ORDER BY id DESC LIMIT 5;" 2>/dev/null
echo "[DONE]"
