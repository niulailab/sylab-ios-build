#!/bin/bash
echo "===== 问题3: /browser/content 抓取实测 ====="
for u in "https://en.wikipedia.org/wiki/Artificial_intelligence" "https://www.baidu.com/" "https://duckduckgo.com/" "https://www.bing.com/"; do
  R=$(curl -s --max-time 28 -X POST http://127.0.0.1:9092/browser/content -H 'Content-Type: application/json' -d "{\"url\":\"$u\"}")
  echo "$R" | python3 -c "
import json,sys
u='$u'
try:
 d=json.load(sys.stdin)
 c=d.get('content') or d.get('text') or d.get('data') or ''
 if isinstance(c,(dict,list)): c=json.dumps(c,ensure_ascii=False)
 print(f'  {u[:45]:45} HTTP字段code={d.get(\"code\",\"-\")} 内容长度={len(str(c))}')
except Exception as e: print(f'  {u[:45]:45} 解析失败/非200: {str(sys.stdin.read())[:80]}')
"
done
echo ""
echo "===== 问题4: /screenshot 截图实测 ====="
for u in "https://en.wikipedia.org/wiki/Artificial_intelligence" "https://www.baidu.com/"; do
  code=$(curl -s --max-time 35 -o /tmp/scr_resp.json -w '%{http_code}' -X POST http://127.0.0.1:9092/screenshot -H 'Content-Type: application/json' -d "{\"url\":\"$u\"}")
  python3 -c "
import json
u='$u'; code='$code'
try:
 d=json.load(open('/tmp/scr_resp.json'))
 b=d.get('screenshot_base64') or d.get('image') or d.get('data') or ''
 print(f'  {u[:45]:45} HTTP={code} base64长度={len(str(b))} msg={d.get(\"msg\",d.get(\"error\",\"-\"))}')
except Exception as e: print(f'  {u[:45]:45} HTTP={code} 非JSON/空: {open(\"/tmp/scr_resp.json\").read()[:80]}')
"
done
echo ""
echo "===== browser-service 最近日志(反爬/空页/重启痕迹) ====="
docker logs browser-service --since 4m 2>&1 | grep -iE "200|empty|block|timeout|error|restart|crash" | tail -12
echo "[DONE]"
