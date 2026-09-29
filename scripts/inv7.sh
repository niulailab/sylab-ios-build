#!/bin/bash
echo "### 运行时读取 model_instance 的代码 ###"
timeout 50 grep -rniE "model_instance|ModelInstance|GetModelInstance|modelInstance" /root/coze-studio/backend --include=*.go 2>/dev/null | grep -viE "_test|\.bak|api/model" | head -15
echo ""
echo "### fallback_chatmodel.go 里模型加载/思考 ###"
grep -nE "model_instance|ModelInstance|thinking|Thinking|connection|Connection|cache|Cache" /root/coze-studio/backend/bizpkg/llm/modelbuilder/fallback_chatmodel.go 2>/dev/null | head -20
echo ""
echo "### 含 agent_id 的 bot版本类表 ###"
MP=$(docker exec coze-mysql printenv MYSQL_ROOT_PASSWORD)
docker exec coze-mysql mysql -uroot -p"$MP" opencoze -e "SELECT table_name FROM information_schema.tables WHERE table_schema='opencoze' AND table_name LIKE '%agent%version%';" 2>/dev/null
echo "[DONE]"
