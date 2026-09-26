#!/bin/bash
set +e
cat > /etc/nginx/sites-available/sylab-web <<'EOF'
server {
    listen 8099 ssl;
    listen [::]:8099 ssl;
    server_name web.symsgf.xyz;

    ssl_certificate /etc/nginx/ssl/direct.crt;
    ssl_certificate_key /etc/nginx/ssl/direct.key;
    ssl_protocols TLSv1.2 TLSv1.3;

    allow 173.245.48.0/20;
    allow 103.21.244.0/22;
    allow 103.22.200.0/22;
    allow 103.31.4.0/22;
    allow 141.101.64.0/18;
    allow 108.162.192.0/18;
    allow 190.93.240.0/20;
    allow 188.114.96.0/20;
    allow 197.234.240.0/22;
    allow 198.41.128.0/17;
    allow 162.158.0.0/15;
    allow 104.16.0.0/13;
    allow 104.24.0.0/14;
    allow 172.64.0.0/13;
    allow 131.0.72.0/22;
    allow 127.0.0.1;
    allow ::1;
    deny all;

    root /root/sylab-app/web-build;
    index index.html;

    gzip on;
    gzip_types text/css application/javascript application/json image/svg+xml;
    gzip_min_length 1024;

    location / {
        try_files $uri $uri/ /index.html;
    }
}
EOF
ln -sf /etc/nginx/sites-available/sylab-web /etc/nginx/sites-enabled/sylab-web
nginx -t 2>&1
if nginx -t 2>/dev/null; then systemctl reload nginx; echo RELOAD_OK; fi
echo "===== local SNI curl ====="
curl -s -k --resolve web.symsgf.xyz:8099:127.0.0.1 "https://web.symsgf.xyz:8099/" -o /tmp/wb.html -w "http=%{http_code} bytes=%{size_download}\n"
head -c 400 /tmp/wb.html; echo
echo "===== entry bundle referenced ====="
grep -oE '_expo/static/js/web/[^"]+\.js' /tmp/wb.html | head
