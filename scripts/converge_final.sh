#!/bin/bash
echo "===== 重启前容器启动时长 ====="
docker ps --format '{{.Names}} -> {{.Status}}' | grep -E "coze-server|tool-proxy"

echo "===== 1. 干净重启 coze-server + tool-proxy（不碰node熔断）====="
docker restart coze-server tool-proxy >/dev/null
sleep 16

echo "===== 2. 必须是秒级/分钟内的新进程 ====="
docker ps --format '{{.Names}} -> {{.Status}}' | grep -E "coze-server|tool-proxy"

echo "===== 3. 启动健康检查（无fatal/panic）====="
docker logs coze-server --since 40s 2>&1 | grep -iE "panic|fatal|exceeds|crash" | head -5
[ -z "$(docker logs coze-server --since 40s 2>&1 | grep -iE 'panic|fatal')" ] && echo "coze-server 启动无致命错误"

echo "===== 4. DB最终配置（必须flash直连）====="
MP=$(docker exec coze-mysql printenv MYSQL_ROOT_PASSWORD)
docker exec coze-mysql mysql -uroot -p"$MP" opencoze -N -e "SELECT connection FROM model_instance WHERE id=100015;" 2>/dev/null | python3 -c "import json,sys;b=json.load(sys.stdin)['base_conn_info'];print('model =',b['model']);print('url   =',b['base_url'])"

echo "===== 5. 直连flash实测思考（确认链路+思考正常）====="
python3 - <<'PY'
import json,urllib.request
KEY="674ea22cd4af46508ab1baa22d3a6fc6.mSy1BrBipXy3pnoG"
req=urllib.request.Request("https://open.bigmodel.cn/api/paas/v4/chat/completions",
  data=json.dumps({"model":"glm-5.3-flash","max_tokens":2048,
    "messages":[{"role":"user","content":"9.11和9.9哪个大？只回答数字。"}]}).encode(),
  headers={"Authorization":f"Bearer {KEY}","Content-Type":"application/json"})
d=json.load(urllib.request.urlopen(req,timeout=120))
m=d["choices"][0]["message"]
print("答案 =",(m.get("content") or "").strip())
print("思考长度 =",len((m.get("reasoning_content") or "").strip()),"(flash默认档，>100即思考充足)")
PY

echo "===== 6. 端口与熔断服务确认（未受影响）====="
curl -s -o /dev/null -w "code-exec 9097:%{http_code}\n" -X POST http://127.0.0.1:9097/execute -H 'Content-Type: application/json' -d '{"code":"echo z","language":"shell"}'
systemctl is-active code-exec.service | xargs echo "code-exec systemd:"
echo "[CONVERGE DONE]"
