#!/bin/bash
set -o pipefail
python3 - <<'PYEOF'
#!/usr/bin/env python3
import json, subprocess, urllib.request, sys, time

def mysql(sql):
    out = subprocess.run(
        ['docker','exec','-e','Q='+sql,'coze-mysql','sh','-c',
         'mysql -uroot -p"$MYSQL_ROOT_PASSWORD" -N --default-character-set=utf8mb4 -e "$Q"'],
        capture_output=True)
    return out.stdout.decode('utf-8','replace')

# 1) 定位最近含“这套提炼”的会话
rows = mysql("SELECT conversation_id FROM opencoze.message WHERE role='user' AND content LIKE '%这套提炼%' ORDER BY id DESC LIMIT 3;")
cands=[r.strip() for r in rows.splitlines() if r.strip()]
print('conv candidates:', cands)
cid = cands[0]
print('using cid', cid)

# 2) 取该会话最近30条 user/assistant（按 id 升序）
data = mysql("SELECT role, content FROM opencoze.message WHERE conversation_id=%s AND role IN ('user','assistant') ORDER BY id DESC LIMIT 30;" % cid)
msgs=[]
for line in data.splitlines():
    parts=line.split('\t',1)
    if len(parts)==2:
        role='user' if parts[0]=='user' else 'assistant'
        msgs.append({'role':role,'content':parts[1]})
msgs.reverse()
print('fetched msgs:', len(msgs))
for m in msgs:
    print(' ', m['role'], m['content'][:40].replace('\n',' '))

transcript='\n'.join(('用户：' if m['role']=='user' else 'AI：')+m['content'][:4000] for m in msgs)[:24000]
prompt='''你是“技能提炼器”。下面给你一段用户与 AI 的真实对话，请判断其中是否存在可复用的固定流程；若有，提炼成一个结构化技能。

【硬性要求】
- 只输出一个 JSON 对象，不要输出任何解释，不要使用 markdown 代码块。
- JSON 字段：
{"name":"技能名","icon":"一个emoji","category":"分类","trigger":"什么场景下用","tools":["可能用到的工具"],"params":[{"name":"参数名","required":true,"desc":"说明","example":""}],"content":"标准操作流程Markdown，需含 # 标题、## 目标、## 输入参数、## 步骤、## 输出、## 约束"}
- content 的步骤要编号、可执行；对话中没有明确参数时 params 给空数组 []。
- 技能要能脱离本次具体内容复用（把具体商品名/主题抽象成参数）。
- 若对话没有可复用流程，返回 {"empty":true,"reason":"原因"}。

【待提炼对话】
'''+transcript

body={
 'bot_id':'7669580347859795968',
 'user_id':'repro-extract',
 'stream':True,
 'auto_save_history':False,
 'additional_messages':[{'role':'user','content':prompt,'content_type':'text'}],
}
req=urllib.request.Request('http://127.0.0.1:9091/v3/chat',
    data=json.dumps(body).encode(),
    headers={'Content-Type':'application/json','Authorization':'Bearer pat_fb5f8dccaaf858b78152bff3788686c76a46a4bfe95736eb94441da0d40e6ed4'})
t0=time.time()
answer=[]
events=set()
toolnames=[]
rawtail=[]
with urllib.request.urlopen(req, timeout=300) as r:
    cur=''
    for raw in r:
        line=raw.decode('utf-8','replace').rstrip('\n')
        rawtail.append(line)
        if len(rawtail)>40: rawtail=rawtail[-40:]
        if line.startswith('event:'):
            cur=line[6:].strip(); events.add(cur)
        elif line.startswith('data:'):
            ds=line[5:].strip()
            if not ds or ds=='[DONE]': continue
            try: ev=json.loads(ds)
            except: continue
            if cur=='conversation.message.delta':
                msg=ev.get('message_item',ev)
                typ=(msg.get('type') or msg.get('message_type') or '').lower()
                if (not typ or typ in ('answer','text')) and msg.get('content'):
                    answer.append(msg['content'])
                tcs=msg.get('tool_calls') or ev.get('tool_calls')
                if tcs:
                    for tc in tcs:
                        toolnames.append(tc.get('function',{}).get('name') or tc.get('name'))

full=''.join(answer)
print('\n===== RESULT =====')
print('elapsed %.1fs'%(time.time()-t0))
print('events:', sorted(events))
print('tool calls:', toolnames)
print('answer length:', len(full))
print('--- answer head 500 ---'); print(full[:500])
print('--- answer tail 500 ---'); print(full[-500:])
# 尝试解析
try:
    t=full.strip()
    import re
    f=re.search(r'```(?:json)?\s*([\s\S]*?)```',t)
    if f: t=f.group(1).strip()
    s=t.find('{'); e=t.rfind('}')
    if s>=0 and e>s: t=t[s:e+1]
    obj=json.loads(t)
    print('JSON PARSE OK; empty=',obj.get('empty'),'name=',obj.get('name'),'content_len=',len(str(obj.get('content',''))))
except Exception as ex:
    print('JSON PARSE FAILED:', ex)
PYEOF
