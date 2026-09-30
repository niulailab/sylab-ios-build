#!/usr/bin/env bash
exec > /var/www/sylab-ios/fix1_0930.txt 2>&1
set +e
cd /root/coze-studio/docker || exit 1
F=docker-compose.yml
TS=$(date +%Y%m%d_%H%M%S)
BAK="${F}.bak_dnsfix_${TS}"
cp "$F" "$BAK"
echo "backup=$BAK"

python3 - "$F" <<'PY'
import sys
p=sys.argv[1]; s=open(p).read()
old1="""  coze-server:
    image: cozedev/coze-studio-server:coderunner-0923
    restart: always
    container_name: coze-server
    env_file: *id001
    networks:
      coze-network:
        ipv4_address: 172.18.0.103
"""
new1="""  coze-server:
    image: cozedev/coze-studio-server:coderunner-0923
    restart: always
    container_name: coze-server
    extra_hosts:
    - "tool-proxy:172.18.0.10"
    env_file: *id001
    networks:
      coze-network:
        ipv4_address: 172.18.0.103
"""
old2="""    networks:
    - coze-network
    depends_on:
      minio:
        condition: service_healthy
  browser-service:
"""
new2="""    networks:
      coze-network:
        ipv4_address: 172.18.0.10
    depends_on:
      minio:
        condition: service_healthy
  browser-service:
"""
for i,(o,n) in enumerate([(old1,new1),(old2,new2)],1):
    c=s.count(o); print(f"anchor{i} matches={c}")
    if c!=1:
        print("ABORT: anchor not unique"); sys.exit(3)
    s=s.replace(o,n)
open(p,"w").write(s)
print("patched ok")
PY

if [ $? -ne 0 ]; then
  echo "PATCH_FAILED -> restoring backup"
  cp "$BAK" "$F"
  exit 1
fi

echo
echo "##### docker compose config 校验"
docker compose -f "$F" config >/dev/null 2>config_err.txt && echo "CONFIG_OK" || { echo "CONFIG_INVALID:"; cat config_err.txt; cp "$BAK" "$F"; echo "已恢复备份"; }
echo
echo "##### 改动确认 (grep)"
grep -n "extra_hosts\|tool-proxy:172" "$F"
grep -n -A2 "^  tool-proxy:" "$F" | head; 
