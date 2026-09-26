#!/bin/bash
echo "===== nginx -T (server_name/listen/ssl/root) ====="
nginx -T 2>/dev/null | grep -nE "server_name|listen |ssl_certificate|root |location " | head -80
echo "===== conf files ====="
ls -la /etc/nginx/conf.d/ /etc/nginx/sites-enabled/ 2>/dev/null
echo "===== certs ====="
ls -la /etc/nginx/ssl /etc/letsencrypt/live 2>/dev/null
