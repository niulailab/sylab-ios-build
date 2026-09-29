#!/bin/bash
echo "=== chat endpoints in tool-proxy server.py ==="
grep -nE "/v1/chat|/v3/chat|chat/completions|def .*chat|UPSTREAM|upstream|llm-proxy|LLM_PROXY|glm|bigmodel|zhipu|paas/v4|retrieve" /root/coze-studio/tool-proxy/server.py | head -40
echo
echo "=== self-built tables referenced in code (schedule etc) & HCL file ==="
ls -la /root/coze-studio/docker/atlas/ 2>/dev/null | head
grep -nE "schedule|byok|api_key|CREATE TABLE|scheduled" /root/coze-studio/docker/atlas/opencoze_latest_schema.hcl 2>/dev/null | head
echo
echo "=== existing custom tables in mysql ==="
docker exec coze-minio sh -c 'true' 2>/dev/null; docker exec coze-mysql mysql -uroot -pd3G8JG273iE8C4irRWJX opencoze -N -e "SHOW TABLES;" 2>/dev/null | grep -iE "schedule|byok|credential|custom|sylab" 
echo "[DONE]"
