#!/bin/bash
cd /root/sylab-app
echo "===== web deps ====="
node -e "const p=require('./package.json');const d={...p.dependencies,...p.devDependencies};for(const k of ['react-native-web','react-dom','@expo/metro-runtime'])console.log(k, d[k]||'MISSING')"
echo "===== web build dir? ====="
ls -la dist web-build 2>/dev/null || echo "no web build"
echo "===== listening ports ====="
ss -ltnp 2>/dev/null | grep -E ':8081|:19006|:8088|:5000|:3000' || echo "no expo/web ports"
echo "===== nginx sites ====="
ls /etc/nginx/conf.d/ 2>/dev/null; grep -rlE "server_name|proxy_pass" /etc/nginx/conf.d/ 2>/dev/null | head
