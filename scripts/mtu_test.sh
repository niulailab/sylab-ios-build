#!/bin/bash
echo "=== host ifaces/MTU ==="
ip -br link show | awk '{print $1,$NF}'
ip route get 8.8.8.8 2>/dev/null | head -1
echo "=== docker net MTU ==="
docker network inspect bridge --format '{{.Name}} mtu={{.Options.Mtu}}' 2>/dev/null
docker inspect browser-service --format '{{range $k,$v := .NetworkSettings.Networks}}{{$k}} {{end}}'
echo "=== container iface MTU ==="
docker exec browser-service sh -c 'cat /sys/class/net/eth0/mtu; ip route | head -3'
echo "=== TLS with small packet (MSS probe) vs normal ==="
cat > /tmp/_tls.py <<'PY'
import socket, ssl, sys
sites=["www.baidu.com","www.qq.com","example.com","github.com"]
for host in sites:
    ip=socket.getaddrinfo(host,443,socket.AF_INET)[0][4][0]
    # normal
    try:
        s=socket.create_connection((ip,443),timeout=8)
        ctx=ssl.create_default_context()
        ss=ctx.wrap_socket(s,server_hostname=host)
        print(host,"NORMAL TLS OK",ss.version()); ss.close()
    except Exception as e:
        print(host,"NORMAL ERR",repr(e)[:120])
    # forced low MTU via setsockopt TCP_MAXSEG (linux)
    try:
        s=socket.create_connection((ip,443),timeout=8)
        try: s.setsockopt(socket.IPPROTO_TCP, socket.TCP_MAXSEG, 1200)
        except Exception as me: print("  mss set fail",me)
        ctx=ssl.create_default_context()
        ss=ctx.wrap_socket(s,server_hostname=host)
        print(host,"LOW-MSS TLS OK",ss.version()); ss.close()
    except Exception as e:
        print(host,"LOW-MSS ERR",repr(e)[:120])
PY
docker cp /tmp/_tls.py browser-service:/tmp/_tls.py
docker exec browser-service python3 -u /tmp/_tls.py 2>&1
echo "=== big packet ping (MTU path probe) from host ==="
for sz in 1472 1452 1400 1200; do
 ping -M do -c1 -s $sz -W3 8.8.8.8 >/dev/null 2>&1 && echo "host payload $sz OK" || echo "host payload $sz FAIL"
done
echo "[DONE]"
