#!/bin/bash
echo "===== A. openapi.json 实际路由清单 ====="
curl -s http://127.0.0.1:9092/openapi.json -o /tmp/openapi.json
wc -c /tmp/openapi.json
python3 - <<'PY'
import json
d=json.load(open("/tmp/openapi.json"))
paths=sorted(d.get("paths",{}).keys())
print("路由总数:",len(paths))
for p in paths: print("  ",p)
PY

echo ""
echo "===== B. agent_tool_version 表结构 ====="
MP=$(docker exec coze-mysql printenv MYSQL_ROOT_PASSWORD)
docker exec coze-mysql mysql -uroot -p"$MP" opencoze -e "SELECT column_name FROM information_schema.columns WHERE table_schema='opencoze' AND table_name='agent_tool_version' ORDER BY ordinal_position;" 2>/dev/null | tr '\n' ' '
echo ""

echo "===== C. sylab bot 已注册工具（该bot 7669580347859795968）====="
docker exec coze-mysql mysql -uroot -p"$MP" opencoze -e "SELECT tool_id, name, LEFT(description,40) d FROM agent_tool_version WHERE agent_id=7669580347859795968 ORDER BY name;" 2>/dev/null
echo "[DONE]"
