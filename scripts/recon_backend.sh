#!/usr/bin/env bash
OUT() { echo; echo "######## $1 ########"; }
OUT "A. /root/coze-studio top level"
ls -la /root/coze-studio 2>/dev/null | head -60

OUT "B. locate memory-service source (bounded)"
for d in /root/coze-studio /root /data; do
  find "$d" -maxdepth 4 -type d -iname '*memory*' 2>/dev/null
done | sort -u | head -40

OUT "C. memory-service container mounts & workdir"
docker inspect coze-memory-service --format 'IMAGE={{.Config.Image}}
WORKDIR={{.Config.WorkingDir}}
MOUNTS:
{{range .Mounts}}  {{.Source}} -> {{.Destination}} ({{.Mode}})
{{end}}' 2>/dev/null

OUT "D. memory-service files inside container (top)"
docker exec coze-memory-service sh -lc 'pwd; ls -la; echo "--- find py files ---"; find . -maxdepth 3 -name "*.py" 2>/dev/null | head -60' 2>/dev/null

OUT "E. memory DB tables (live data dir)"
for db in /data/coze-studio-data/memory-service/memory.db /data/coze-studio-data/memory-service/memories.db; do
  echo "-- $db"
  [ -f "$db" ] && python3 -c "import sqlite3;c=sqlite3.connect('$db');[print(r[0]) for r in c.execute(\"select name from sqlite_master where type='table'\")]" 2>/dev/null
done

OUT "F. kg tables schema (entity/relation)"
for db in /data/coze-studio-data/memory-service/memory.db; do
  [ -f "$db" ] || continue
  for t in kg_entities kg_relations entities relations; do
    python3 -c "import sqlite3;c=sqlite3.connect('$db');
r=c.execute(\"select sql from sqlite_master where name='$t'\").fetchone();
print('-- $t:'); print(r[0] if r else 'absent')" 2>/dev/null
  done
done
echo RECON_BACKEND_DONE
