#!/bin/bash
echo "===== nginx listening ports ====="
ss -ltnp | grep -E ':80 |:443 |:8099 |:8091 ' | awk '{print $4}'
echo "===== ufw ====="
ufw status 2>/dev/null | head -20
echo "===== iptables filter (INPUT) ====="
iptables -L INPUT -n --line-numbers 2>/dev/null | head -30
echo "===== iptables NAT/port hints ====="
iptables -t nat -L PREROUTING -n 2>/dev/null | grep -E 'dpt:(80|443|8099)' | head
echo "===== self connect test ====="
for p in 80 443 8099; do timeout 3 bash -c "echo > /dev/tcp/127.0.0.1/$p" 2>/dev/null && echo "local $p OK" || echo "local $p NO"; done
echo "===== public iface ip ====="
ip -4 addr show | grep -E 'inet ' | grep -v 127.0.0.1
