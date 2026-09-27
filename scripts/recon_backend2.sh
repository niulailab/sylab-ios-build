#!/usr/bin/env bash
set +e
echo "######## A. main.py routes ########"
grep -nE '@app\.(get|post|put|delete)' /root/coze-studio/docker/memory-service-custom/main.py
echo
echo "######## B. main.py: collection / collection_name usage ########"
grep -nE "collection|collection_name|CREATE TABLE|INSERT INTO|def " /root/coze-studio/docker/memory-service-custom/main.py | head -80
echo
echo "######## C. memories table schema ########"
sqlite3 /data/coze-studio-data/memory-service/memory.db ".schema memories"
echo "-- memories columns only --"
sqlite3 /data/coze-studio-data/memory-service/memory.db "PRAGMA table_info(memories);"
echo "-- sample row (trimmed) --"
sqlite3 /data/coze-studio-data/memory-service/memory.db "SELECT id,substr(coalesce(agent_id,''),1,12),type,substr(coalesce(content,''),1,60) FROM memories LIMIT 3;"
echo
echo "######## D. Go backend memory client / call sites ########"
grep -rnE "8900|memory-service|/kg|/memory/" /root/coze-studio/backend --include=*.go | grep -vE '_test.go' | head -40
echo
echo "######## E. Go tool registration dirs ########"
ls -1 /root/coze-studio/backend/domain/tool 2>/dev/null | head
echo "-- tool impl subdirs (bounded) --"
find /root/coze-studio/backend -type d -name '*tool*' 2>/dev/null | head -30
echo
echo "######## F. where tools are registered (search keyword) ########"
grep -rnE "RegisterTool|ToolName|registerTool|NewTool|tools\.Register" /root/coze-studio/backend --include=*.go | grep -vE '_test.go' | head -30
echo
echo "######## G. system prompt assembly points ########"
grep -rnE "system_prompt|SystemPrompt|systemPrompt|prompt_template|PromptTemplate" /root/coze-studio/backend --include=*.go | grep -vE '_test.go' | head -30
echo
echo "######## H. existing skill/preset keyword in Go ########"
grep -rniE "\bskill\b" /root/coze-studio/backend --include=*.go | grep -vE '_test.go' | head -20
echo
echo "RECON2_DONE"
