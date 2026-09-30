# -*- coding: utf-8 -*-
import json, subprocess, time, sys
import pymysql

def rootpw():
    return subprocess.check_output(["docker","exec","coze-mysql","printenv","MYSQL_ROOT_PASSWORD"]).decode().strip()

conn=pymysql.connect(host="127.0.0.1",user="root",password=rootpw(),database="opencoze",charset="utf8mb4",autocommit=False)
cur=conn.cursor()

BOT=7669580347859795968
CUR=7669597666208120832
SPACE=7666842042261045248
DEV=7666848996043784192
now=int(time.time()*1000)
_seq=[0]
def nid():
    _seq[0]+=1
    return (now<<12)+_seq[0]

def col(table):
    cur.execute("SELECT column_name FROM information_schema.columns WHERE table_schema='opencoze' AND table_name=%s",(table,))
    return {r[0] for r in cur.fetchall()}

T_cols=col("tool"); ATV_cols=col("agent_tool_version")

# ---------- Step 1: bind existing tools ----------
existing_bind = [
    7667500000000001002,  # /video/generate
    7667500000000001003,  # /video/status/{task_id}
    7668100000000000102,  # /git_operation
]
report=[]
for tid in existing_bind:
    cur.execute("SELECT plugin_id,sub_url,method,operation,version FROM tool WHERE id=%s",(tid,))
    r=cur.fetchone()
    if not r:
        report.append(f"bind SKIP {tid}: no tool row"); continue
    plugin_id,sub_url,method,operation,version=r
    # operation may be dict already or str
    op_str = operation if isinstance(operation,str) else json.dumps(operation,ensure_ascii=False)
    op_obj = json.loads(op_str)
    tool_name = op_obj.get("operationId") or sub_url.strip("/").replace("/","_")
    cur.execute("SELECT id FROM agent_tool_version WHERE agent_id=%s AND agent_version=%s AND tool_id=%s",(BOT,CUR,tid))
    if cur.fetchone():
        report.append(f"bind EXISTS {tool_name}"); continue
    bid=nid()
    cur.execute("""INSERT INTO agent_tool_version
      (id,agent_id,plugin_id,tool_id,agent_version,tool_name,tool_version,sub_url,method,operation,created_at,source)
      VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,0)""",
      (bid,BOT,plugin_id,tid,CUR,tool_name,str(version or "1.0.0"),sub_url,method,op_str,now))
    report.append(f"bind OK {tool_name} ({sub_url})")

# ---------- Step 2: create sylab_extra plugin ----------
EXTRA_NAME="sylab_extra_tools"
cur.execute("SELECT id FROM plugin WHERE id=%s",(7668000000000000999,))
if cur.fetchone():
    EXTRA=7668000000000000999
    report.append("plugin EXISTS sylab_extra")
else:
    EXTRA=7668000000000000999
    manifest={"api":{"type":"openapi"},"auth":{"type":"none","payload":"","sub_type":""},
      "logo_url":"default_icon/plugin_default_icon.png","common_params":{},
      "name_for_human":"sylab扩展工具集","name_for_model":EXTRA_NAME,"schema_version":"v1",
      "description_for_human":"sylab平台后期新增的扩展能力集合","description_for_model":"Extra sylab platform capabilities."}
    cur.execute("""INSERT INTO plugin
      (id,space_id,developer_id,app_id,icon_uri,server_url,plugin_type,created_at,updated_at,version,version_desc,manifest,openapi_doc)
      VALUES (%s,%s,%s,0,%s,%s,1,%s,%s,'v1.0.0','Extra tools',%s,NULL)""",
      (EXTRA,SPACE,DEV,"default_icon/plugin_default_icon.png","http://tool-proxy:9092",now,now,json.dumps(manifest,ensure_ascii=False)))
    pvid=7668000000000001000
    cur.execute("""INSERT INTO plugin_version
      (id,space_id,developer_id,plugin_id,app_id,icon_uri,server_url,plugin_type,version,version_desc,manifest,openapi_doc,created_at,deleted_at)
      VALUES (%s,%s,%s,%s,0,%s,%s,1,'1.0.0',NULL,%s,NULL,%s,NULL)""",
      (pvid,SPACE,DEV,EXTRA,"default_icon/plugin_default_icon.png","http://tool-proxy:9092",json.dumps(manifest,ensure_ascii=False),now))
    report.append("plugin OK sylab_extra")

# ---------- Step 3: define new tools ----------
def op(oid,summary,desc,body_props=None,required=None,params=None,resp_extra=None):
    o={"summary":summary,"description":desc,"operationId":oid,"x-operation-type":"tool"}
    if params is not None:
        o["parameters"]=params
    if body_props is not None:
        o["requestBody"]={"content":{"application/json":{"schema":{"type":"object",
            "properties":body_props, **({"required":required} if required else {})}}},
            "required":bool(required)}
    o["responses"]={"200":{"description":"Success","content":{"application/json":{"schema":{"type":"object","properties":{
        "code":{"type":"integer"},"msg":{"type":"string"},
        "data":{"type":"string","description":"JSON string payload"}}}}}}}
    return o

S={"type":"string"}
new_tools=[
 ("publish_web","POST","/publish_web",
   op("publish_web","Publish static HTML to public web","Store an HTML page and return a public inline-renderable URL with read-back verification.",
      {"html":S,"title":S,"filename":S},["html"])),
 ("create_notification","POST","/notifications/create",
   op("create_notification","Create a user notification","Send a notification to a user; supports SSE push.",
      {"title":S,"content":S,"notif_type":S,"user_id":{"type":"string"},"conversation_id":S},["title","content"])),
 ("list_notifications","GET","/notifications/list",
   op("list_notifications","List notifications","List current user notifications.",
      {"page":{"type":"integer"},"size":{"type":"integer"},"only_unread":{"type":"boolean"}},[])),
 ("mark_notification_read","POST","/notifications/mark-read",
   op("mark_notification_read","Mark notification read","Mark one or all notifications as read.",
      {"id":{"type":"string"},"all":{"type":"boolean"}},[])),
 ("delete_notification","POST","/notifications/delete",
   op("delete_notification","Delete a notification","Delete a notification by id.",
      {"id":{"type":"string"}},["id"])),
 ("schedule_toggle","POST","/schedule/toggle",
   op("schedule_toggle","Enable or disable a schedule","Pause or resume a scheduled task without deleting it.",
      {"schedule_id":{"type":"string"},"enabled":{"type":"boolean"}},["schedule_id","enabled"])),
 ("bigmodel_proxy","POST","/bigmodel/v1/{path}",
   op("bigmodel_proxy","Zhipu BigModel API proxy","Generic passthrough proxy to the Zhipu BigModel API. Path selects the endpoint; body is forwarded.",
      [{"in":"path","name":"path","schema":{"type":"string"},"required":True,"description":"BigModel API sub-path"}])),
 ("get_video_content","GET","/video/content/{task_id}",
   op("get_video_content","Get generated video content","Retrieve the generated video file/stream for a task.",
      [{"in":"path","name":"task_id","schema":{"type":"string"},"required":True,"description":"Video task id"}])),
]

for name,method,sub_url,operation in new_tools:
    op_str=json.dumps(operation,ensure_ascii=False)
    cur.execute("SELECT id FROM tool WHERE plugin_id=%s AND sub_url=%s AND method=%s",(EXTRA,sub_url,method))
    row=cur.fetchone()
    if row:
        tid=row[0]; report.append(f"tool EXISTS {name}")
    else:
        tid=nid()
        cur.execute("""INSERT INTO tool
          (id,plugin_id,created_at,updated_at,version,sub_url,method,operation,activated_status)
          VALUES (%s,%s,%s,%s,'v1.0.0',%s,%s,%s,1)""",
          (tid,EXTRA,now,now,sub_url,method,op_str))
        report.append(f"tool OK {name}")
    cur.execute("SELECT id FROM agent_tool_version WHERE agent_id=%s AND agent_version=%s AND tool_id=%s",(BOT,CUR,tid))
    if cur.fetchone():
        report.append(f"  bind EXISTS {name}"); continue
    bid=nid()
    cur.execute("""INSERT INTO agent_tool_version
      (id,agent_id,plugin_id,tool_id,agent_version,tool_name,tool_version,sub_url,method,operation,created_at,source)
      VALUES (%s,%s,%s,%s,%s,%s,'v1.0.0',%s,%s,%s,%s,0)""",
      (bid,BOT,EXTRA,tid,CUR,name,sub_url,method,op_str,now))
    report.append(f"  bind OK {name}")

conn.commit()
print("\n".join(report))
cur.execute("SELECT COUNT(*) FROM agent_tool_version WHERE agent_id=%s AND agent_version=%s",(BOT,CUR))
print("CURRENT VERSION TOTAL BINDINGS =",cur.fetchone()[0])
cur.close();conn.close()
