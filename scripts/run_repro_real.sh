#!/bin/bash
python3 - <<'PYEOF'
import json, subprocess, urllib.request, re, time, datetime
CID='7689892369646223360'
def mysql(sql):
    p=subprocess.run(['docker','exec','-e','Q='+sql,'coze-mysql','sh','-c',
      'mysql -uroot -p"$MYSQL_ROOT_PASSWORD" -N --default-character-set=utf8mb4 -e "$Q" 2>/dev/null'],capture_output=True)
    return p.stdout.decode('utf-8','replace')
# 取该会话全部 user/assistant，按 id；模拟 store 顺序
rows=mysql("SELECT role,content FROM opencoze.message WHERE conversation_id=%s AND role IN ('user','assistant') ORDER BY id;"%CID)
allm=[]
for line in rows.split('\n'):
    if '\t' in line:
        r,c=line.split('\t',1); allm.append({'role':r,'content':c})
print('total user/assistant rows:',len(allm))
# 设备过滤
filt=[m for m in allm if not re.search(r'task_id|任务ID|进度[：:]?\s*\d+%|视频正在生成',m['content'])]
last=filt[-30:]
src=[{'role':m['role'],'content':m['content']} for m in last if m['content'].strip()]
print('source n=',len(src))
for m in src:
    print('  ',m['role'],m['content'][:35].replace('\n',' '))
transcript='\n'.join(('用户：' if m['role']=='user' else 'AI：')+m['content'][:4000] for m in src)[:24000]
print('transcript chars=',len(transcript))
prompt=open('/tmp/p.txt').read()+transcript if False else '''你是“技能提炼器”。下面给你一段用户与 AI 的真实对话，请判断其中是否存在可复用的固定流程；若有，提炼成一个结构化技能。

【硬性要求】
- 只输出一个 JSON 对象，不要输出任何解释，不要使用 markdown 代码块。
- JSON 字段：
{"name":"技能名","icon":"一个emoji","category":"分类","trigger":"什么场景下用","tools":["可能用到的工具"],"params":[{"name":"参数名","required":true,"desc":"说明","example":""}],"content":"标准操作流程Markdown，需含 # 标题、## 目标、## 输入参数、## 步骤、## 输出、## 约束"}
- content 的步骤要编号、可执行；对话中没有明确参数时 params 给空数组 []。
- 技能要能脱离本次具体内容复用（把具体商品名/主题抽象成参数）。
- 若对话没有可复用流程，返回 {"empty":true,"reason":"原因"}。

【待提炼对话】
'''+transcript
body={'bot_id':'7669580347859795968','user_id':'repro-real','stream':True,'auto_save_history':False,
 'additional_messages':[{'role':'user','content':prompt,'content_type':'text'}]}
req=urllib.request.Request('http://127.0.0.1:9091/v3/chat',data=json.dumps(body).encode(),
 headers={'Content-Type':'application/json','Authorization':'Bearer pat_fb5f8dccaaf858b78152bff3788686c76a46a4bfe95736eb94441da0d40e6ed4'})
ans=[]; events=set(); tools=[]; cur=''
t0=time.time()
with urllib.request.urlopen(req,timeout=300) as r:
    for raw in r:
        line=raw.decode('utf-8','replace').rstrip()
        if line.startswith('event:'): cur=line[6:].strip(); events.add(cur)
        elif line.startswith('data:'):
            ds=line[5:].strip()
            if not ds or ds=='[DONE]':continue
            try: ev=json.loads(ds)
            except: continue
            if cur=='conversation.message.delta':
                msg=ev.get('message_item',ev); typ=(msg.get('type') or msg.get('message_type') or '').lower()
                if (not typ or typ in ('answer','text')) and msg.get('content'): ans.append(msg['content'])
                tcs=msg.get('tool_calls') or ev.get('tool_calls')
                if tcs:
                    for tc in tcs: tools.append(tc.get('function',{}).get('name') or tc.get('name'))
full=''.join(ans)
print('\n==== RESULT elapsed %.1fs'%(time.time()-t0))
print('events',sorted(events),'tools',tools,'answer_len',len(full))
print('HEAD:',full[:300]); print('TAIL:',full[-300:])
try:
    t=full.strip(); f=re.search(r'```(?:json)?\s*([\s\S]*?)```',t)
    if f:t=f.group(1).strip()
    s=t.find('{');e=t.rfind('}');t=t[s:e+1]
    obj=json.loads(t); print('PARSE OK name=',obj.get('name'),'clen=',len(str(obj.get('content',''))))
except Exception as ex: print('PARSE FAIL:',repr(ex))
PYEOF
